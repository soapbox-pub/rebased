defmodule Pleroma.Web.ActivityPub.ActivityPub do
  alias Pleroma.Repo
  alias Pleroma.{Activity, Object, Upload, User}
  import Ecto.Query

  def insert(map) when is_map(map) do
    map = map
    |> Map.put_new_lazy("id", &generate_activity_id/0)
    |> Map.put_new_lazy("published", &make_date/0)

    map = if is_map(map["object"]) do
      object = Map.put_new_lazy(map["object"], "id", &generate_object_id/0)
      Repo.insert!(%Object{data: object})
      Map.put(map, "object", object)
    else
      map
    end

    Repo.insert(%Activity{data: map})
  end

  def like(%User{ap_id: ap_id} = user, %Object{data: %{ "id" => id}} = object) do
    cond do
      # There's already a like here, so return the original activity.
      ap_id in (object.data["likes"] || []) ->
        query = from activity in Activity,
          where: fragment("? @> ?", activity.data, ^%{actor: ap_id, object: id})

        activity = Repo.one(query)
        {:ok, activity, object}
      true ->
        data = %{
          "type" => "Like",
          "actor" => ap_id,
          "object" => id,
          "to" => [User.ap_followers(user)]
        }

        {:ok, activity} = insert(data)

        likes = [ap_id | (object.data["likes"] || [])] |> Enum.uniq

        new_data = object.data
        |> Map.put("like_count", length(likes))
        |> Map.put("likes", likes)

        changeset = Ecto.Changeset.change(object, data: new_data)
        {:ok, object} = Repo.update(changeset)

        # Update activities that already had this. Could be done in a seperate process.
        relevant_activities = Activity.all_by_object_ap_id(id)
        Enum.map(relevant_activities, fn (activity) ->
          new_activity_data = activity.data |> Map.put("object", new_data)
          changeset = Ecto.Changeset.change(activity, data: new_activity_data)
          Repo.update(changeset)
        end)
        {:ok, activity, object}
    end
  end

  def generate_activity_id do
    generate_id("activities")
  end

  def generate_context_id do
    generate_id("contexts")
  end

  def generate_object_id do
    generate_id("objects")
  end

  def generate_id(type) do
    "#{Pleroma.Web.base_url()}/#{type}/#{Ecto.UUID.generate}"
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

    query = if opts["max_id"] do
      from activity in query, where: activity.id < ^opts["max_id"]
    else
      query
    end

    Repo.all(query)
    |> Enum.reverse
  end

  def fetch_activities_for_context(context) do
    query = from activity in Activity,
      where: fragment("? @> ?", activity.data, ^%{ context: context })
    Repo.all(query)
  end

  def upload(%Plug.Upload{} = file) do
    data = Upload.store(file)
    Repo.insert(%Object{data: data})
  end

  defp make_date do
    DateTime.utc_now() |> DateTime.to_iso8601
  end
end
