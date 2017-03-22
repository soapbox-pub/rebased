defmodule Pleroma.Web.ActivityPub.ActivityPub do
  alias Pleroma.Repo
  alias Pleroma.Activity
  import Ecto.Query

  def insert(map) when is_map(map) do
    Repo.insert(%Activity{data: map})
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

    Repo.all(query)
    |> Enum.reverse
  end
end
