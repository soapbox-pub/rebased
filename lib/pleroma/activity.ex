# Pleroma: A lightweight social networking server
# Copyright © 2017-2019 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Activity do
  use Ecto.Schema

  alias Pleroma.Activity
  alias Pleroma.Bookmark
  alias Pleroma.Notification
  alias Pleroma.Object
  alias Pleroma.Repo
  alias Pleroma.User

  import Ecto.Changeset
  import Ecto.Query

  @type t :: %__MODULE__{}
  @type actor :: String.t()

  @primary_key {:id, Pleroma.FlakeId, autogenerate: true}

  # https://github.com/tootsuite/mastodon/blob/master/app/models/notification.rb#L19
  @mastodon_notification_types %{
    "Create" => "mention",
    "Follow" => "follow",
    "Announce" => "reblog",
    "Like" => "favourite"
  }

  @mastodon_to_ap_notification_types for {k, v} <- @mastodon_notification_types,
                                         into: %{},
                                         do: {v, k}

  schema "activities" do
    field(:data, :map)
    field(:local, :boolean, default: true)
    field(:actor, :string)
    field(:recipients, {:array, :string}, default: [])
    # This is a fake relation, do not use outside of with_preloaded_bookmark/get_bookmark
    has_one(:bookmark, Bookmark)
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

    timestamps()
  end

  def with_joined_object(query) do
    join(query, :inner, [activity], o in Object,
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

  def with_preloaded_object(query) do
    query
    |> has_named_binding?(:object)
    |> if(do: query, else: with_joined_object(query))
    |> preload([activity, object: object], object: object)
  end

  def with_preloaded_bookmark(query, %User{} = user) do
    from([a] in query,
      left_join: b in Bookmark,
      on: b.user_id == ^user.id and b.activity_id == a.id,
      preload: [bookmark: b]
    )
  end

  def with_preloaded_bookmark(query, _), do: query

  def get_by_ap_id(ap_id) do
    Repo.one(
      from(
        activity in Activity,
        where: fragment("(?)->>'id' = ?", activity.data, ^to_string(ap_id))
      )
    )
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
    Repo.one(
      from(
        activity in Activity,
        where: fragment("(?)->>'id' = ?", activity.data, ^to_string(ap_id)),
        left_join: o in Object,
        on:
          fragment(
            "(?->>'id') = COALESCE(?->'object'->>'id', ?->>'object')",
            o.data,
            activity.data,
            activity.data
          ),
        preload: [object: o]
      )
    )
  end

  def get_by_id(id) do
    Activity
    |> where([a], a.id == ^id)
    |> restrict_deactivated_users()
    |> Repo.one()
  end

  def get_by_id_with_object(id) do
    from(activity in Activity,
      where: activity.id == ^id,
      inner_join: o in Object,
      on:
        fragment(
          "(?->>'id') = COALESCE(?->'object'->>'id', ?->>'object')",
          o.data,
          activity.data,
          activity.data
        ),
      preload: [object: o]
    )
    |> Repo.one()
  end

  def by_object_ap_id(ap_id) do
    from(
      activity in Activity,
      where:
        fragment(
          "coalesce((?)->'object'->>'id', (?)->>'object') = ?",
          activity.data,
          activity.data,
          ^to_string(ap_id)
        )
    )
  end

  def create_by_object_ap_id(ap_ids) when is_list(ap_ids) do
    from(
      activity in Activity,
      where:
        fragment(
          "coalesce((?)->'object'->>'id', (?)->>'object') = ANY(?)",
          activity.data,
          activity.data,
          ^ap_ids
        ),
      where: fragment("(?)->>'type' = 'Create'", activity.data)
    )
  end

  def create_by_object_ap_id(ap_id) when is_binary(ap_id) do
    from(
      activity in Activity,
      where:
        fragment(
          "coalesce((?)->'object'->>'id', (?)->>'object') = ?",
          activity.data,
          activity.data,
          ^to_string(ap_id)
        ),
      where: fragment("(?)->>'type' = 'Create'", activity.data)
    )
  end

  def create_by_object_ap_id(_), do: nil

  def get_all_create_by_object_ap_id(ap_id) do
    Repo.all(create_by_object_ap_id(ap_id))
  end

  def get_create_by_object_ap_id(ap_id) when is_binary(ap_id) do
    create_by_object_ap_id(ap_id)
    |> restrict_deactivated_users()
    |> Repo.one()
  end

  def get_create_by_object_ap_id(_), do: nil

  def create_by_object_ap_id_with_object(ap_id) when is_binary(ap_id) do
    from(
      activity in Activity,
      where:
        fragment(
          "coalesce((?)->'object'->>'id', (?)->>'object') = ?",
          activity.data,
          activity.data,
          ^to_string(ap_id)
        ),
      where: fragment("(?)->>'type' = 'Create'", activity.data),
      inner_join: o in Object,
      on:
        fragment(
          "(?->>'id') = COALESCE(?->'object'->>'id', ?->>'object')",
          o.data,
          activity.data,
          activity.data
        ),
      preload: [object: o]
    )
  end

  def create_by_object_ap_id_with_object(_), do: nil

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

  def get_in_reply_to_activity(%Activity{data: %{"object" => object}}) do
    get_in_reply_to_activity_from_object(Object.normalize(object))
  end

  def normalize(obj) when is_map(obj), do: get_by_ap_id_with_object(obj["id"])
  def normalize(ap_id) when is_binary(ap_id), do: get_by_ap_id_with_object(ap_id)
  def normalize(_), do: nil

  def delete_by_ap_id(id) when is_binary(id) do
    by_object_ap_id(id)
    |> select([u], u)
    |> Repo.delete_all()
    |> elem(1)
    |> Enum.find(fn
      %{data: %{"type" => "Create", "object" => ap_id}} when is_binary(ap_id) -> ap_id == id
      %{data: %{"type" => "Create", "object" => %{"id" => ap_id}}} -> ap_id == id
      _ -> nil
    end)
  end

  def delete_by_ap_id(_), do: nil

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
    from(
      a in Activity,
      where:
        fragment(
          "? ->> 'type' = 'Follow'",
          a.data
        ),
      where:
        fragment(
          "? ->> 'state' = 'pending'",
          a.data
        ),
      where:
        fragment(
          "coalesce((?)->'object'->>'id', (?)->>'object') = ?",
          a.data,
          a.data,
          ^ap_id
        )
    )
  end

  @spec query_by_actor(actor()) :: Ecto.Query.t()
  def query_by_actor(actor) do
    from(a in Activity, where: a.actor == ^actor)
  end

  def restrict_deactivated_users(query) do
    from(activity in query,
      where:
        fragment(
          "? not in (SELECT ap_id FROM users WHERE info->'deactivated' @> 'true')",
          activity.actor
        )
    )
  end
end
