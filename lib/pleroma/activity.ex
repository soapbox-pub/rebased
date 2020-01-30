# Pleroma: A lightweight social networking server
# Copyright © 2017-2019 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Activity do
  use Ecto.Schema

  alias Pleroma.Activity
  alias Pleroma.Activity.Queries
  alias Pleroma.ActivityExpiration
  alias Pleroma.Bookmark
  alias Pleroma.Notification
  alias Pleroma.Object
  alias Pleroma.Repo
  alias Pleroma.ReportNote
  alias Pleroma.ThreadMute
  alias Pleroma.User

  import Ecto.Changeset
  import Ecto.Query

  @type t :: %__MODULE__{}
  @type actor :: String.t()

  @primary_key {:id, FlakeId.Ecto.CompatType, autogenerate: true}

  # https://github.com/tootsuite/mastodon/blob/master/app/models/notification.rb#L19
  @mastodon_notification_types %{
    "Create" => "mention",
    "Follow" => "follow",
    "Announce" => "reblog",
    "Like" => "favourite",
    "Move" => "move",
    "EmojiReaction" => "pleroma:emoji_reaction"
  }

  @mastodon_to_ap_notification_types for {k, v} <- @mastodon_notification_types,
                                         into: %{},
                                         do: {v, k}

  schema "activities" do
    field(:data, :map)
    field(:local, :boolean, default: true)
    field(:actor, :string)
    field(:recipients, {:array, :string}, default: [])
    field(:thread_muted?, :boolean, virtual: true)

    # This is a fake relation,
    # do not use outside of with_preloaded_user_actor/with_joined_user_actor
    has_one(:user_actor, User, on_delete: :nothing, foreign_key: :id)
    # This is a fake relation, do not use outside of with_preloaded_bookmark/get_bookmark
    has_one(:bookmark, Bookmark)
    # This is a fake relation, do not use outside of with_preloaded_report_notes
    has_many(:report_notes, ReportNote)
    has_many(:notifications, Notification, on_delete: :delete_all)

    # Attention: this is a fake relation, don't try to preload it blindly and expect it to work!
    # The foreign key is embedded in a jsonb field.
    #
    # To use it, you probably want to do an inner join and a preload:
    #
    # ```
    # |> join(:inner, [activity], o in Object,
    #      on: fragment("(?->>'id') = COALESCE((?)->'object'->> 'id', (?)->>'object')",
    #        o.data, activity.data, activity.data))
    # |> preload([activity, object], [object: object])
    # ```
    #
    # As a convenience, Activity.with_preloaded_object() sets up an inner join and preload for the
    # typical case.
    has_one(:object, Object, on_delete: :nothing, foreign_key: :id)

    has_one(:expiration, ActivityExpiration, on_delete: :delete_all)

    timestamps()
  end

  def with_joined_object(query, join_type \\ :inner) do
    join(query, join_type, [activity], o in Object,
      on:
        fragment(
          "(?->>'id') = COALESCE(?->'object'->>'id', ?->>'object')",
          o.data,
          activity.data,
          activity.data
        ),
      as: :object
    )
  end

  def with_preloaded_object(query, join_type \\ :inner) do
    query
    |> has_named_binding?(:object)
    |> if(do: query, else: with_joined_object(query, join_type))
    |> preload([activity, object: object], object: object)
  end

  def with_joined_user_actor(query, join_type \\ :inner) do
    join(query, join_type, [activity], u in User,
      on: u.ap_id == activity.actor,
      as: :user_actor
    )
  end

  def with_preloaded_user_actor(query, join_type \\ :inner) do
    query
    |> with_joined_user_actor(join_type)
    |> preload([activity, user_actor: user_actor], user_actor: user_actor)
  end

  def with_preloaded_bookmark(query, %User{} = user) do
    from([a] in query,
      left_join: b in Bookmark,
      on: b.user_id == ^user.id and b.activity_id == a.id,
      preload: [bookmark: b]
    )
  end

  def with_preloaded_bookmark(query, _), do: query

  def with_preloaded_report_notes(query) do
    from([a] in query,
      left_join: r in ReportNote,
      on: a.id == r.activity_id,
      preload: [report_notes: r]
    )
  end

  def with_preloaded_report_notes(query, _), do: query

  def with_set_thread_muted_field(query, %User{} = user) do
    from([a] in query,
      left_join: tm in ThreadMute,
      on: tm.user_id == ^user.id and tm.context == fragment("?->>'context'", a.data),
      as: :thread_mute,
      select: %Activity{a | thread_muted?: not is_nil(tm.id)}
    )
  end

  def with_set_thread_muted_field(query, _), do: query

  def get_by_ap_id(ap_id) do
    ap_id
    |> Queries.by_ap_id()
    |> Repo.one()
  end

  def get_bookmark(%Activity{} = activity, %User{} = user) do
    if Ecto.assoc_loaded?(activity.bookmark) do
      activity.bookmark
    else
      Bookmark.get(user.id, activity.id)
    end
  end

  def get_bookmark(_, _), do: nil

  def change(struct, params \\ %{}) do
    struct
    |> cast(params, [:data, :recipients])
    |> validate_required([:data])
    |> unique_constraint(:ap_id, name: :activities_unique_apid_index)
  end

  def get_by_ap_id_with_object(ap_id) do
    ap_id
    |> Queries.by_ap_id()
    |> with_preloaded_object(:left)
    |> Repo.one()
  end

  @spec get_by_id(String.t()) :: Activity.t() | nil
  def get_by_id(id) do
    case FlakeId.flake_id?(id) do
      true ->
        Activity
        |> where([a], a.id == ^id)
        |> restrict_deactivated_users()
        |> Repo.one()

      _ ->
        nil
    end
  end

  def get_by_id_with_object(id) do
    Activity
    |> where(id: ^id)
    |> with_preloaded_object()
    |> Repo.one()
  end

  def all_by_ids_with_object(ids) do
    Activity
    |> where([a], a.id in ^ids)
    |> with_preloaded_object()
    |> Repo.all()
  end

  @doc """
  Accepts `ap_id` or list of `ap_id`.
  Returns a query.
  """
  @spec create_by_object_ap_id(String.t() | [String.t()]) :: Ecto.Queryable.t()
  def create_by_object_ap_id(ap_id) do
    ap_id
    |> Queries.by_object_id()
    |> Queries.by_type("Create")
  end

  def get_all_create_by_object_ap_id(ap_id) do
    ap_id
    |> create_by_object_ap_id()
    |> Repo.all()
  end

  def get_create_by_object_ap_id(ap_id) when is_binary(ap_id) do
    create_by_object_ap_id(ap_id)
    |> restrict_deactivated_users()
    |> Repo.one()
  end

  def get_create_by_object_ap_id(_), do: nil

  @doc """
  Accepts `ap_id` or list of `ap_id`.
  Returns a query.
  """
  @spec create_by_object_ap_id_with_object(String.t() | [String.t()]) :: Ecto.Queryable.t()
  def create_by_object_ap_id_with_object(ap_id) do
    ap_id
    |> create_by_object_ap_id()
    |> with_preloaded_object()
  end

  def get_create_by_object_ap_id_with_object(ap_id) when is_binary(ap_id) do
    ap_id
    |> create_by_object_ap_id_with_object()
    |> Repo.one()
  end

  def get_create_by_object_ap_id_with_object(_), do: nil

  defp get_in_reply_to_activity_from_object(%Object{data: %{"inReplyTo" => ap_id}}) do
    get_create_by_object_ap_id_with_object(ap_id)
  end

  defp get_in_reply_to_activity_from_object(_), do: nil

  def get_in_reply_to_activity(%Activity{} = activity) do
    get_in_reply_to_activity_from_object(Object.normalize(activity))
  end

  def normalize(obj) when is_map(obj), do: get_by_ap_id_with_object(obj["id"])
  def normalize(ap_id) when is_binary(ap_id), do: get_by_ap_id_with_object(ap_id)
  def normalize(_), do: nil

  def delete_all_by_object_ap_id(id) when is_binary(id) do
    id
    |> Queries.by_object_id()
    |> Queries.exclude_type("Delete")
    |> select([u], u)
    |> Repo.delete_all()
    |> elem(1)
    |> Enum.find(fn
      %{data: %{"type" => "Create", "object" => ap_id}} when is_binary(ap_id) -> ap_id == id
      %{data: %{"type" => "Create", "object" => %{"id" => ap_id}}} -> ap_id == id
      _ -> nil
    end)
    |> purge_web_resp_cache()
  end

  def delete_all_by_object_ap_id(_), do: nil

  defp purge_web_resp_cache(%Activity{} = activity) do
    %{path: path} = URI.parse(activity.data["id"])
    Cachex.del(:web_resp_cache, path)
    activity
  end

  defp purge_web_resp_cache(nil), do: nil

  for {ap_type, type} <- @mastodon_notification_types do
    def mastodon_notification_type(%Activity{data: %{"type" => unquote(ap_type)}}),
      do: unquote(type)
  end

  def mastodon_notification_type(%Activity{}), do: nil

  def from_mastodon_notification_type(type) do
    Map.get(@mastodon_to_ap_notification_types, type)
  end

  def all_by_actor_and_id(actor, status_ids \\ [])
  def all_by_actor_and_id(_actor, []), do: []

  def all_by_actor_and_id(actor, status_ids) do
    Activity
    |> where([s], s.id in ^status_ids)
    |> where([s], s.actor == ^actor)
    |> Repo.all()
  end

  def follow_requests_for_actor(%Pleroma.User{ap_id: ap_id}) do
    ap_id
    |> Queries.by_object_id()
    |> Queries.by_type("Follow")
    |> where([a], fragment("? ->> 'state' = 'pending'", a.data))
  end

  def restrict_deactivated_users(query) do
    deactivated_users =
      from(u in User.Query.build(deactivated: true), select: u.ap_id)
      |> Repo.all()

    Activity.Queries.exclude_authors(query, deactivated_users)
  end

  defdelegate search(user, query, options \\ []), to: Pleroma.Activity.Search

  def direct_conversation_id(activity, for_user) do
    alias Pleroma.Conversation.Participation

    with %{data: %{"context" => context}} when is_binary(context) <- activity,
         %Pleroma.Conversation{} = conversation <- Pleroma.Conversation.get_for_ap_id(context),
         %Participation{id: participation_id} <-
           Participation.for_user_and_conversation(for_user, conversation) do
      participation_id
    else
      _ -> nil
    end
  end
end
