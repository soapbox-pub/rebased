defmodule Pleroma.Web.ActivityPub.Utils do
  alias Pleroma.{Repo, Web, Object, Activity, User}
  alias Pleroma.Web.Router.Helpers
  alias Pleroma.Web.Endpoint
  alias Ecto.{Changeset, UUID}
  import Ecto.Query
  require Logger

  # Some implementations send the actor URI as the actor field, others send the entire actor object,
  # so figure out what the actor's URI is based on what we have.
  def get_ap_id(object) do
    case object do
      %{"id" => id} -> id
      id -> id
    end
  end

  def normalize_params(params) do
    Map.put(params, "actor", get_ap_id(params["actor"]))
  end

  defp recipient_in_collection(ap_id, coll) when is_binary(coll), do: ap_id == coll
  defp recipient_in_collection(ap_id, coll) when is_list(coll), do: ap_id in coll
  defp recipient_in_collection(_, _), do: false

  def recipient_in_message(ap_id, params) do
    cond do
      recipient_in_collection(ap_id, params["to"]) ->
        true

      recipient_in_collection(ap_id, params["cc"]) ->
        true

      recipient_in_collection(ap_id, params["bto"]) ->
        true

      recipient_in_collection(ap_id, params["bcc"]) ->
        true

      # if the message is unaddressed at all, then assume it is directly addressed
      # to the recipient
      !params["to"] && !params["cc"] && !params["bto"] && !params["bcc"] ->
        true

      true ->
        false
    end
  end

  defp extract_list(target) when is_binary(target), do: [target]
  defp extract_list(lst) when is_list(lst), do: lst
  defp extract_list(_), do: []

  def maybe_splice_recipient(ap_id, params) do
    need_splice =
      !recipient_in_collection(ap_id, params["to"]) &&
        !recipient_in_collection(ap_id, params["cc"])

    cc_list = extract_list(params["cc"])

    if need_splice do
      params
      |> Map.put("cc", [ap_id | cc_list])
    else
      params
    end
  end

  def make_json_ld_header do
    %{
      "@context" => [
        "https://www.w3.org/ns/activitystreams",
        "https://litepub.github.io/litepub/context.jsonld"
      ]
    }
  end

  def make_date do
    DateTime.utc_now() |> DateTime.to_iso8601()
  end

  def generate_activity_id do
    generate_id("activities")
  end

  def generate_context_id do
    generate_id("contexts")
  end

  def generate_object_id do
    Helpers.o_status_url(Endpoint, :object, UUID.generate())
  end

  def generate_id(type) do
    "#{Web.base_url()}/#{type}/#{UUID.generate()}"
  end

  def get_notified_from_object(object) do
    User.get_notified_from_activity(%Activity{data: object}, false)
  end

  def create_context(context) do
    context = context || generate_id("contexts")
    changeset = Object.context_mapping(context)

    case Repo.insert(changeset) do
      {:ok, object} ->
        object

      # This should be solved by an upsert, but it seems ecto
      # has problems accessing the constraint inside the jsonb.
      {:error, _} ->
        Object.get_cached_by_ap_id(context)
    end
  end

  @doc """
  Enqueues an activity for federation if it's local
  """
  def maybe_federate(%Activity{local: true} = activity) do
    priority =
      case activity.data["type"] do
        "Delete" -> 10
        "Create" -> 1
        _ -> 5
      end

    Pleroma.Web.Federator.enqueue(:publish, activity, priority)
    :ok
  end

  def maybe_federate(_), do: :ok

  @doc """
  Adds an id and a published data if they aren't there,
  also adds it to an included object
  """
  def lazy_put_activity_defaults(map) do
    %{data: %{"id" => context}, id: context_id} = create_context(map["context"])

    map =
      map
      |> Map.put_new_lazy("id", &generate_activity_id/0)
      |> Map.put_new_lazy("published", &make_date/0)
      |> Map.put_new("context", context)
      |> Map.put_new("context_id", context_id)

    if is_map(map["object"]) do
      object = lazy_put_object_defaults(map["object"], map)
      %{map | "object" => object}
    else
      map
    end
  end

  @doc """
  Adds an id and published date if they aren't there.
  """
  def lazy_put_object_defaults(map, activity \\ %{}) do
    map
    |> Map.put_new_lazy("id", &generate_object_id/0)
    |> Map.put_new_lazy("published", &make_date/0)
    |> Map.put_new("context", activity["context"])
    |> Map.put_new("context_id", activity["context_id"])
  end

  @doc """
  Inserts a full object if it is contained in an activity.
  """
  def insert_full_object(%{"object" => %{"type" => type} = object_data})
      when is_map(object_data) and type in ["Article", "Note", "Video", "Page"] do
    with {:ok, _} <- Object.create(object_data) do
      :ok
    end
  end

  def insert_full_object(_), do: :ok

  def update_object_in_activities(%{data: %{"id" => id}} = object) do
    # TODO
    # Update activities that already had this. Could be done in a seperate process.
    # Alternatively, just don't do this and fetch the current object each time. Most
    # could probably be taken from cache.
    relevant_activities = Activity.all_by_object_ap_id(id)

    Enum.map(relevant_activities, fn activity ->
      new_activity_data = activity.data |> Map.put("object", object.data)
      changeset = Changeset.change(activity, data: new_activity_data)
      Repo.update(changeset)
    end)
  end

  #### Like-related helpers

  @doc """
  Returns an existing like if a user already liked an object
  """
  def get_existing_like(actor, %{data: %{"id" => id}}) do
    query =
      from(
        activity in Activity,
        where: fragment("(?)->>'actor' = ?", activity.data, ^actor),
        # this is to use the index
        where:
          fragment(
            "coalesce((?)->'object'->>'id', (?)->>'object') = ?",
            activity.data,
            activity.data,
            ^id
          ),
        where: fragment("(?)->>'type' = 'Like'", activity.data)
      )

    Repo.one(query)
  end

  def make_like_data(%User{ap_id: ap_id} = actor, %{data: %{"id" => id}} = object, activity_id) do
    data = %{
      "type" => "Like",
      "actor" => ap_id,
      "object" => id,
      "to" => [actor.follower_address, object.data["actor"]],
      "cc" => ["https://www.w3.org/ns/activitystreams#Public"],
      "context" => object.data["context"]
    }

    if activity_id, do: Map.put(data, "id", activity_id), else: data
  end

  def update_element_in_object(property, element, object) do
    with new_data <-
           object.data
           |> Map.put("#{property}_count", length(element))
           |> Map.put("#{property}s", element),
         changeset <- Changeset.change(object, data: new_data),
         {:ok, object} <- Repo.update(changeset),
         _ <- update_object_in_activities(object) do
      {:ok, object}
    end
  end

  def update_likes_in_object(likes, object) do
    update_element_in_object("like", likes, object)
  end

  def add_like_to_object(%Activity{data: %{"actor" => actor}}, object) do
    likes = if is_list(object.data["likes"]), do: object.data["likes"], else: []

    with likes <- [actor | likes] |> Enum.uniq() do
      update_likes_in_object(likes, object)
    end
  end

  def remove_like_from_object(%Activity{data: %{"actor" => actor}}, object) do
    likes = if is_list(object.data["likes"]), do: object.data["likes"], else: []

    with likes <- likes |> List.delete(actor) do
      update_likes_in_object(likes, object)
    end
  end

  #### Follow-related helpers

  @doc """
  Updates a follow activity's state (for locked accounts).
  """
  def update_follow_state(%Activity{} = activity, state) do
    with new_data <-
           activity.data
           |> Map.put("state", state),
         changeset <- Changeset.change(activity, data: new_data),
         {:ok, activity} <- Repo.update(changeset) do
      {:ok, activity}
    end
  end

  @doc """
  Makes a follow activity data for the given follower and followed
  """
  def make_follow_data(
        %User{ap_id: follower_id},
        %User{ap_id: followed_id} = followed,
        activity_id
      ) do
    data = %{
      "type" => "Follow",
      "actor" => follower_id,
      "to" => [followed_id],
      "cc" => ["https://www.w3.org/ns/activitystreams#Public"],
      "object" => followed_id,
      "state" => "pending"
    }

    data = if activity_id, do: Map.put(data, "id", activity_id), else: data

    data
  end

  def fetch_latest_follow(%User{ap_id: follower_id}, %User{ap_id: followed_id}) do
    query =
      from(
        activity in Activity,
        where:
          fragment(
            "? ->> 'type' = 'Follow'",
            activity.data
          ),
        where: activity.actor == ^follower_id,
        where:
          fragment(
            "? @> ?",
            activity.data,
            ^%{object: followed_id}
          ),
        order_by: [desc: :id],
        limit: 1
      )

    Repo.one(query)
  end

  #### Announce-related helpers

  @doc """
  Retruns an existing announce activity if the notice has already been announced
  """
  def get_existing_announce(actor, %{data: %{"id" => id}}) do
    query =
      from(
        activity in Activity,
        where: activity.actor == ^actor,
        # this is to use the index
        where:
          fragment(
            "coalesce((?)->'object'->>'id', (?)->>'object') = ?",
            activity.data,
            activity.data,
            ^id
          ),
        where: fragment("(?)->>'type' = 'Announce'", activity.data)
      )

    Repo.one(query)
  end

  @doc """
  Make announce activity data for the given actor and object
  """
  # for relayed messages, we only want to send to subscribers
  def make_announce_data(
        %User{ap_id: ap_id, nickname: nil} = user,
        %Object{data: %{"id" => id}} = object,
        activity_id
      ) do
    data = %{
      "type" => "Announce",
      "actor" => ap_id,
      "object" => id,
      "to" => [user.follower_address],
      "cc" => [],
      "context" => object.data["context"]
    }

    if activity_id, do: Map.put(data, "id", activity_id), else: data
  end

  def make_announce_data(
        %User{ap_id: ap_id} = user,
        %Object{data: %{"id" => id}} = object,
        activity_id
      ) do
    data = %{
      "type" => "Announce",
      "actor" => ap_id,
      "object" => id,
      "to" => [user.follower_address, object.data["actor"]],
      "cc" => ["https://www.w3.org/ns/activitystreams#Public"],
      "context" => object.data["context"]
    }

    if activity_id, do: Map.put(data, "id", activity_id), else: data
  end

  @doc """
  Make unannounce activity data for the given actor and object
  """
  def make_unannounce_data(
        %User{ap_id: ap_id} = user,
        %Activity{data: %{"context" => context}} = activity,
        activity_id
      ) do
    data = %{
      "type" => "Undo",
      "actor" => ap_id,
      "object" => activity.data,
      "to" => [user.follower_address, activity.data["actor"]],
      "cc" => ["https://www.w3.org/ns/activitystreams#Public"],
      "context" => context
    }

    if activity_id, do: Map.put(data, "id", activity_id), else: data
  end

  def make_unlike_data(
        %User{ap_id: ap_id} = user,
        %Activity{data: %{"context" => context}} = activity,
        activity_id
      ) do
    data = %{
      "type" => "Undo",
      "actor" => ap_id,
      "object" => activity.data,
      "to" => [user.follower_address, activity.data["actor"]],
      "cc" => ["https://www.w3.org/ns/activitystreams#Public"],
      "context" => context
    }

    if activity_id, do: Map.put(data, "id", activity_id), else: data
  end

  def add_announce_to_object(
        %Activity{
          data: %{"actor" => actor, "cc" => ["https://www.w3.org/ns/activitystreams#Public"]}
        },
        object
      ) do
    announcements =
      if is_list(object.data["announcements"]), do: object.data["announcements"], else: []

    with announcements <- [actor | announcements] |> Enum.uniq() do
      update_element_in_object("announcement", announcements, object)
    end
  end

  def add_announce_to_object(_, object), do: {:ok, object}

  def remove_announce_from_object(%Activity{data: %{"actor" => actor}}, object) do
    announcements =
      if is_list(object.data["announcements"]), do: object.data["announcements"], else: []

    with announcements <- announcements |> List.delete(actor) do
      update_element_in_object("announcement", announcements, object)
    end
  end

  #### Unfollow-related helpers

  def make_unfollow_data(follower, followed, follow_activity, activity_id) do
    data = %{
      "type" => "Undo",
      "actor" => follower.ap_id,
      "to" => [followed.ap_id],
      "object" => follow_activity.data
    }

    if activity_id, do: Map.put(data, "id", activity_id), else: data
  end

  #### Block-related helpers
  def fetch_latest_block(%User{ap_id: blocker_id}, %User{ap_id: blocked_id}) do
    query =
      from(
        activity in Activity,
        where:
          fragment(
            "? ->> 'type' = 'Block'",
            activity.data
          ),
        where: activity.actor == ^blocker_id,
        where:
          fragment(
            "? @> ?",
            activity.data,
            ^%{object: blocked_id}
          ),
        order_by: [desc: :id],
        limit: 1
      )

    Repo.one(query)
  end

  def make_block_data(blocker, blocked, activity_id) do
    data = %{
      "type" => "Block",
      "actor" => blocker.ap_id,
      "to" => [blocked.ap_id],
      "object" => blocked.ap_id
    }

    if activity_id, do: Map.put(data, "id", activity_id), else: data
  end

  def make_unblock_data(blocker, blocked, block_activity, activity_id) do
    data = %{
      "type" => "Undo",
      "actor" => blocker.ap_id,
      "to" => [blocked.ap_id],
      "object" => block_activity.data
    }

    if activity_id, do: Map.put(data, "id", activity_id), else: data
  end

  #### Create-related helpers

  def make_create_data(params, additional) do
    published = params.published || make_date()

    %{
      "type" => "Create",
      "to" => params.to |> Enum.uniq(),
      "actor" => params.actor.ap_id,
      "object" => params.object,
      "published" => published,
      "context" => params.context
    }
    |> Map.merge(additional)
  end
end
