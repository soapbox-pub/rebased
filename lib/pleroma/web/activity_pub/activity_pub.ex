defmodule Pleroma.Web.ActivityPub.ActivityPub do
  alias Pleroma.Repo
  alias Pleroma.{Activity, Object, Upload}
  import Ecto.Query

  def insert(map) when is_map(map) do
    map = Map.put_new_lazy(map, "id", &generate_activity_id/0)

    map = if is_map(map["object"]) do
      object = Map.put_new_lazy(map["object"], "id", &generate_object_id/0)
      Repo.insert!(%Object{data: object})
      Map.put(map, "object", object)
    else
      map
    end

    Repo.insert(%Activity{data: map})
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

    query = if opts["actor_id"] do
      from activity in query,
        where: fragment("? @> ?", activity.data, ^%{actor: opts["actor_id"]})
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
end
