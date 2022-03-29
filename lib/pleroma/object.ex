# Pleroma: A lightweight social networking server
# Copyright © 2017-2022 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Object do
  use Ecto.Schema

  import Ecto.Query
  import Ecto.Changeset

  alias Pleroma.Activity
  alias Pleroma.Config
  alias Pleroma.Hashtag
  alias Pleroma.HashtagObject
  alias Pleroma.Object
  alias Pleroma.Object.Fetcher
  alias Pleroma.ObjectTombstone
  alias Pleroma.Repo
  alias Pleroma.User
  alias Pleroma.Workers.AttachmentsCleanupWorker

  require Logger

  @type t() :: %__MODULE__{}

  @primary_key {:id, FlakeId.Ecto.CompatType, autogenerate: true}

  @derive {Jason.Encoder, only: [:data]}

  @cachex Pleroma.Config.get([:cachex, :provider], Cachex)

  schema "objects" do
    field(:data, :map)

    many_to_many(:hashtags, Hashtag, join_through: HashtagObject, on_replace: :delete)

    timestamps()
  end

  def with_joined_activity(query, activity_type \\ "Create", join_type \\ :inner) do
    object_position = Map.get(query.aliases, :object, 0)

    join(query, join_type, [{object, object_position}], a in Activity,
      on:
        fragment(
          "COALESCE(?->'object'->>'id', ?->>'object') = (? ->> 'id') AND (?->>'type' = ?) ",
          a.data,
          a.data,
          object.data,
          a.data,
          ^activity_type
        ),
      as: :object_activity
    )
  end

  def create(data) do
    %Object{}
    |> Object.change(%{data: data})
    |> Repo.insert()
  end

  def change(struct, params \\ %{}) do
    struct
    |> cast(params, [:data])
    |> validate_required([:data])
    |> unique_constraint(:ap_id, name: :objects_unique_apid_index)
    # Expecting `maybe_handle_hashtags_change/1` to run last:
    |> maybe_handle_hashtags_change(struct)
  end

  # Note: not checking activity type (assuming non-legacy objects are associated with Create act.)
  defp maybe_handle_hashtags_change(changeset, struct) do
    with %Ecto.Changeset{valid?: true} <- changeset,
         data_hashtags_change = get_change(changeset, :data),
         {_, true} <- {:changed, hashtags_changed?(struct, data_hashtags_change)},
         {:ok, hashtag_records} <-
           data_hashtags_change
           |> object_data_hashtags()
           |> Hashtag.get_or_create_by_names() do
      put_assoc(changeset, :hashtags, hashtag_records)
    else
      %{valid?: false} ->
        changeset

      {:changed, false} ->
        changeset

      {:error, _} ->
        validate_change(changeset, :data, fn _, _ ->
          [data: "error referencing hashtags"]
        end)
    end
  end

  defp hashtags_changed?(%Object{} = struct, %{"tag" => _} = data) do
    Enum.sort(embedded_hashtags(struct)) !=
      Enum.sort(object_data_hashtags(data))
  end

  defp hashtags_changed?(_, _), do: false

  def get_by_id(nil), do: nil
  def get_by_id(id), do: Repo.get(Object, id)

  def get_by_id_and_maybe_refetch(id, opts \\ []) do
    %{updated_at: updated_at} = object = get_by_id(id)

    if opts[:interval] &&
         NaiveDateTime.diff(NaiveDateTime.utc_now(), updated_at) > opts[:interval] do
      case Fetcher.refetch_object(object) do
        {:ok, %Object{} = object} ->
          object

        e ->
          Logger.error("Couldn't refresh #{object.data["id"]}:\n#{inspect(e)}")
          object
      end
    else
      object
    end
  end

  def get_by_ap_id(nil), do: nil

  def get_by_ap_id(ap_id) do
    Repo.one(from(object in Object, where: fragment("(?)->>'id' = ?", object.data, ^ap_id)))
  end

  @doc """
  Get a single attachment by it's name and href
  """
  @spec get_attachment_by_name_and_href(String.t(), String.t()) :: Object.t() | nil
  def get_attachment_by_name_and_href(name, href) do
    query =
      from(o in Object,
        where: fragment("(?)->>'name' = ?", o.data, ^name),
        where: fragment("(?)->>'href' = ?", o.data, ^href)
      )

    Repo.one(query)
  end

  defp warn_on_no_object_preloaded(ap_id) do
    "Object.normalize() called without preloaded object (#{inspect(ap_id)}). Consider preloading the object"
    |> Logger.debug()

    Logger.debug("Backtrace: #{inspect(Process.info(:erlang.self(), :current_stacktrace))}")
  end

  def normalize(_, options \\ [fetch: false])

  # If we pass an Activity to Object.normalize(), we can try to use the preloaded object.
  # Use this whenever possible, especially when walking graphs in an O(N) loop!
  def normalize(%Object{} = object, _), do: object
  def normalize(%Activity{object: %Object{} = object}, _), do: object

  # A hack for fake activities
  def normalize(%Activity{data: %{"object" => %{"fake" => true} = data}}, _) do
    %Object{id: "pleroma:fake_object_id", data: data}
  end

  # No preloaded object
  def normalize(%Activity{data: %{"object" => %{"id" => ap_id}}}, options) do
    warn_on_no_object_preloaded(ap_id)
    normalize(ap_id, options)
  end

  # No preloaded object
  def normalize(%Activity{data: %{"object" => ap_id}}, options) do
    warn_on_no_object_preloaded(ap_id)
    normalize(ap_id, options)
  end

  # Old way, try fetching the object through cache.
  def normalize(%{"id" => ap_id}, options), do: normalize(ap_id, options)

  def normalize(ap_id, options) when is_binary(ap_id) do
    if Keyword.get(options, :fetch) do
      Fetcher.fetch_object_from_id!(ap_id, options)
    else
      get_cached_by_ap_id(ap_id)
    end
  end

  def normalize(_, _), do: nil

  # Owned objects can only be accessed by their owner
  def authorize_access(%Object{data: %{"actor" => actor}}, %User{ap_id: ap_id}) do
    if actor == ap_id do
      :ok
    else
      {:error, :forbidden}
    end
  end

  # Legacy objects can be accessed by anybody
  def authorize_access(%Object{}, %User{}), do: :ok

  @spec get_cached_by_ap_id(String.t()) :: Object.t() | nil
  def get_cached_by_ap_id(ap_id) do
    key = "object:#{ap_id}"

    with {:ok, nil} <- @cachex.get(:object_cache, key),
         object when not is_nil(object) <- get_by_ap_id(ap_id),
         {:ok, true} <- @cachex.put(:object_cache, key, object) do
      object
    else
      {:ok, object} -> object
      nil -> nil
    end
  end

  def context_mapping(context) do
    Object.change(%Object{}, %{data: %{"id" => context}})
  end

  def make_tombstone(%Object{data: %{"id" => id, "type" => type}}, deleted \\ DateTime.utc_now()) do
    %ObjectTombstone{
      id: id,
      formerType: type,
      deleted: deleted
    }
    |> Map.from_struct()
  end

  def swap_object_with_tombstone(object) do
    tombstone = make_tombstone(object)

    with {:ok, object} <-
           object
           |> Object.change(%{data: tombstone})
           |> Repo.update() do
      Hashtag.unlink(object)
      {:ok, object}
    end
  end

  def delete(%Object{data: %{"id" => id}} = object) do
    with {:ok, _obj} = swap_object_with_tombstone(object),
         deleted_activity = Activity.delete_all_by_object_ap_id(id),
         {:ok, _} <- invalid_object_cache(object) do
      cleanup_attachments(
        Config.get([:instance, :cleanup_attachments]),
        %{"object" => object}
      )

      {:ok, object, deleted_activity}
    end
  end

  @spec cleanup_attachments(boolean(), %{required(:object) => map()}) ::
          {:ok, Oban.Job.t() | nil}
  def cleanup_attachments(true, %{"object" => _} = params) do
    AttachmentsCleanupWorker.enqueue("cleanup_attachments", params)
  end

  def cleanup_attachments(_, _), do: {:ok, nil}

  def prune(%Object{data: %{"id" => _id}} = object) do
    with {:ok, object} <- Repo.delete(object),
         {:ok, _} <- invalid_object_cache(object) do
      {:ok, object}
    end
  end

  def invalid_object_cache(%Object{data: %{"id" => id}}) do
    with {:ok, true} <- @cachex.del(:object_cache, "object:#{id}") do
      @cachex.del(:web_resp_cache, URI.parse(id).path)
    end
  end

  def set_cache(%Object{data: %{"id" => ap_id}} = object) do
    @cachex.put(:object_cache, "object:#{ap_id}", object)
    {:ok, object}
  end

  def update_and_set_cache(changeset) do
    with {:ok, object} <- Repo.update(changeset) do
      set_cache(object)
    end
  end

  def increase_replies_count(ap_id) do
    Object
    |> where([o], fragment("?->>'id' = ?::text", o.data, ^to_string(ap_id)))
    |> update([o],
      set: [
        data:
          fragment(
            """
            safe_jsonb_set(?, '{repliesCount}',
              (coalesce((?->>'repliesCount')::int, 0) + 1)::varchar::jsonb, true)
            """,
            o.data,
            o.data
          )
      ]
    )
    |> Repo.update_all([])
    |> case do
      {1, [object]} -> set_cache(object)
      _ -> {:error, "Not found"}
    end
  end

  defp poll_is_multiple?(%Object{data: %{"anyOf" => [_ | _]}}), do: true

  defp poll_is_multiple?(_), do: false

  def decrease_replies_count(ap_id) do
    Object
    |> where([o], fragment("?->>'id' = ?::text", o.data, ^to_string(ap_id)))
    |> update([o],
      set: [
        data:
          fragment(
            """
            safe_jsonb_set(?, '{repliesCount}',
              (greatest(0, (?->>'repliesCount')::int - 1))::varchar::jsonb, true)
            """,
            o.data,
            o.data
          )
      ]
    )
    |> Repo.update_all([])
    |> case do
      {1, [object]} -> set_cache(object)
      _ -> {:error, "Not found"}
    end
  end

  def increase_vote_count(ap_id, name, actor) do
    with %Object{} = object <- Object.normalize(ap_id, fetch: false),
         "Question" <- object.data["type"] do
      key = if poll_is_multiple?(object), do: "anyOf", else: "oneOf"

      options =
        object.data[key]
        |> Enum.map(fn
          %{"name" => ^name} = option ->
            Kernel.update_in(option["replies"]["totalItems"], &(&1 + 1))

          option ->
            option
        end)

      voters = [actor | object.data["voters"] || []] |> Enum.uniq()

      data =
        object.data
        |> Map.put(key, options)
        |> Map.put("voters", voters)

      object
      |> Object.change(%{data: data})
      |> update_and_set_cache()
    else
      _ -> :noop
    end
  end

  @doc "Updates data field of an object"
  def update_data(%Object{data: data} = object, attrs \\ %{}) do
    object
    |> Object.change(%{data: Map.merge(data || %{}, attrs)})
    |> Repo.update()
  end

  def local?(%Object{data: %{"id" => id}}) do
    String.starts_with?(id, Pleroma.Web.Endpoint.url() <> "/")
  end

  def replies(object, opts \\ []) do
    object = Object.normalize(object, fetch: false)

    query =
      Object
      |> where(
        [o],
        fragment("(?)->>'inReplyTo' = ?", o.data, ^object.data["id"])
      )
      |> order_by([o], asc: o.id)

    if opts[:self_only] do
      actor = object.data["actor"]
      where(query, [o], fragment("(?)->>'actor' = ?", o.data, ^actor))
    else
      query
    end
  end

  def self_replies(object, opts \\ []),
    do: replies(object, Keyword.put(opts, :self_only, true))

  def tags(%Object{data: %{"tag" => tags}}) when is_list(tags), do: tags

  def tags(_), do: []

  def hashtags(%Object{} = object) do
    # Note: always using embedded hashtags regardless whether they are migrated to hashtags table
    #   (embedded hashtags stay in sync anyways, and we avoid extra joins and preload hassle)
    embedded_hashtags(object)
  end

  def embedded_hashtags(%Object{data: data}) do
    object_data_hashtags(data)
  end

  def embedded_hashtags(_), do: []

  def object_data_hashtags(%{"tag" => tags}) when is_list(tags) do
    tags
    |> Enum.filter(fn
      %{"type" => "Hashtag"} = data -> Map.has_key?(data, "name")
      plain_text when is_bitstring(plain_text) -> true
      _ -> false
    end)
    |> Enum.map(fn
      %{"name" => "#" <> hashtag} -> String.downcase(hashtag)
      %{"name" => hashtag} -> String.downcase(hashtag)
      hashtag when is_bitstring(hashtag) -> String.downcase(hashtag)
    end)
    |> Enum.uniq()
    # Note: "" elements (plain text) might occur in `data.tag` for incoming objects
    |> Enum.filter(&(&1 not in [nil, ""]))
  end

  def object_data_hashtags(_), do: []
end
