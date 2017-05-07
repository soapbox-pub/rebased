defmodule Pleroma.Web.ActivityPub.ActivityPub do
  alias Pleroma.{Activity, Repo, Object, Upload, User, Web}
  alias Ecto.{Changeset, UUID}
  import Ecto.Query

  def insert(map, local \\ true) when is_map(map) do
    map = map
    |> Map.put_new_lazy("id", &generate_activity_id/0)
    |> Map.put_new_lazy("published", &make_date/0)

    with %Activity{} = activity <- Activity.get_by_ap_id(map["id"]) do
      {:ok, activity}
    else _e ->
      map = if is_map(map["object"]) do
        object = Map.put_new_lazy(map["object"], "id", &generate_object_id/0)
        Repo.insert!(%Object{data: object})
        Map.put(map, "object", object)
      else
        map
      end

      Repo.insert(%Activity{data: map, local: local})
    end
  end

  def create(to, actor, context, object, additional \\ %{}, published \\ nil, local \\ true) do
    published = published || make_date()

    activity = %{
      "type" => "Create",
      "to" => to |> Enum.uniq,
      "actor" => actor.ap_id,
      "object" => object,
      "published" => published,
      "context" => context
    }
    |> Map.merge(additional)

    with {:ok, activity} <- insert(activity, local) do
      if actor.local do
        Pleroma.Web.Federator.enqueue(:publish, activity)
       end

      {:ok, activity}
    end
  end

  def like(%User{ap_id: ap_id} = user, %Object{data: %{"id" => id}} = object, activity_id \\ nil, local \\ true) do
    cond do
      # There's already a like here, so return the original activity.
      ap_id in (object.data["likes"] || []) ->
        query = from activity in Activity,
          where: fragment("? @> ?", activity.data, ^%{actor: ap_id, object: id, type: "Like"})

        activity = Repo.one(query)
        {:ok, activity, object}
      true ->
        data = %{
          "type" => "Like",
          "actor" => ap_id,
          "object" => id,
          "to" => [User.ap_followers(user), object.data["actor"]],
          "context" => object.data["context"]
        }

        data = if activity_id, do: Map.put(data, "id", activity_id), else: data

        {:ok, activity} = insert(data, local)

        likes = [ap_id | (object.data["likes"] || [])] |> Enum.uniq

        new_data = object.data
        |> Map.put("like_count", length(likes))
        |> Map.put("likes", likes)

        changeset = Changeset.change(object, data: new_data)
        {:ok, object} = Repo.update(changeset)

        update_object_in_activities(object)

        if user.local do
          Pleroma.Web.Federator.enqueue(:publish, activity)
        end

        {:ok, activity, object}
    end
  end

  defp update_object_in_activities(%{data: %{"id" => id}} = object) do
    # TODO
    # Update activities that already had this. Could be done in a seperate process.
    # Alternatively, just don't do this and fetch the current object each time. Most
    # could probably be taken from cache.
    relevant_activities = Activity.all_by_object_ap_id(id)
    Enum.map(relevant_activities, fn (activity) ->
      new_activity_data = activity.data |> Map.put("object", object.data)
      changeset = Changeset.change(activity, data: new_activity_data)
      Repo.update(changeset)
    end)
  end

  def unlike(%User{ap_id: ap_id}, %Object{data: %{ "id" => id}} = object) do
    query = from activity in Activity,
      where: fragment("? @> ?", activity.data, ^%{actor: ap_id, object: id, type: "Like"})

    activity = Repo.one(query)

    if activity do
      # just delete for now...
      {:ok, _activity} = Repo.delete(activity)

      likes = (object.data["likes"] || []) |> List.delete(ap_id)

      new_data = object.data
      |> Map.put("like_count", length(likes))
      |> Map.put("likes", likes)

      changeset = Changeset.change(object, data: new_data)
      {:ok, object} = Repo.update(changeset)

      update_object_in_activities(object)

      {:ok, object}
    else
      {:ok, object}
    end
  end

  def generate_activity_id do
    generate_id("activities")
  end

  def generate_context_id do
    generate_id("contexts")
  end

  def generate_object_id do
    Pleroma.Web.Router.Helpers.o_status_url(Pleroma.Web.Endpoint, :object, Ecto.UUID.generate)
  end

  def generate_id(type) do
    "#{Web.base_url()}/#{type}/#{UUID.generate}"
  end

  def fetch_public_activities(opts \\ %{}) do
    public = ["https://www.w3.org/ns/activitystreams#Public"]
    fetch_activities(public, opts)
  end

  def fetch_activities(recipients, opts \\ %{}) do
    since_id = opts["since_id"] || 0

    query = from activity in Activity,
      limit: 20,
      order_by: [desc: :inserted_at]

    query = Enum.reduce(recipients, query, fn (recipient, q) ->
      map = %{ to: [recipient] }
      from activity in q,
      or_where: fragment(~s(? @> ?), activity.data, ^map)
    end)

    query = from activity in query,
      where: activity.id > ^since_id

    query = if opts["local_only"] do
      from activity in query, where: activity.local == true
    else
      query
    end

    query = if opts["max_id"] do
      from activity in query, where: activity.id < ^opts["max_id"]
    else
      query
    end

    query = if opts["actor_id"] do
      from activity in query,
        where: fragment("? @> ?", activity.data, ^%{actor: opts["actor_id"]})
    else
      query
    end

    Enum.reverse(Repo.all(query))
  end

  def announce(%User{ap_id: ap_id} = user, %Object{data: %{"id" => id}} = object, activity_id \\ nil, local \\ true) do
    data = %{
      "type" => "Announce",
      "actor" => ap_id,
      "object" => id,
      "to" => [User.ap_followers(user), object.data["actor"]],
      "context" => object.data["context"]
    }

    data = if activity_id, do: Map.put(data, "id", activity_id), else: data

    {:ok, activity} = insert(data, local)

    announcements = [ap_id | (object.data["announcements"] || [])] |> Enum.uniq

    new_data = object.data
    |> Map.put("announcement_count", length(announcements))
    |> Map.put("announcements", announcements)

    changeset = Changeset.change(object, data: new_data)
    {:ok, object} = Repo.update(changeset)

    update_object_in_activities(object)

    if user.local do
      Pleroma.Web.Federator.enqueue(:publish, activity)
    end

    {:ok, activity, object}
  end

  def follow(%User{ap_id: follower_id, local: actor_local}, %User{ap_id: followed_id}, local \\ true) do
    data = %{
      "type" => "Follow",
      "actor" => follower_id,
      "to" => [followed_id],
      "object" => followed_id,
      "published" => make_date()
    }

    with {:ok, activity} <- insert(data, local) do
      if actor_local do
        Pleroma.Web.Federator.enqueue(:publish, activity)
       end

      {:ok, activity}
    end
  end

  def unfollow(follower, followed, local \\ true) do
    with follow_activity when not is_nil(follow_activity) <- fetch_latest_follow(follower, followed) do
      data = %{
        "type" => "Undo",
        "actor" => follower.ap_id,
        "to" => [followed.ap_id],
        "object" => follow_activity.data["id"],
        "published" => make_date()
      }

      with {:ok, activity} <- insert(data, local) do
        if follower.local do
          Pleroma.Web.Federator.enqueue(:publish, activity)
        end

        {:ok, activity}
      end
    end
  end

  def fetch_activities_for_context(context) do
    query = from activity in Activity,
      where: fragment("? @> ?", activity.data, ^%{ context: context })
    Repo.all(query)
  end

  def fetch_latest_follow(%User{ap_id: follower_id},
                          %User{ap_id: followed_id}) do
    query = from activity in Activity,
      where: fragment("? @> ?", activity.data, ^%{type: "Follow", actor: follower_id,
                                                  object: followed_id}),
      order_by: [desc: :inserted_at],
      limit: 1
    Repo.one(query)
  end

  def upload(file) do
    data = Upload.store(file)
    Repo.insert(%Object{data: data})
  end

  defp make_date do
    DateTime.utc_now() |> DateTime.to_iso8601
  end
end
