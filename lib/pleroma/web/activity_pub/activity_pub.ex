defmodule Pleroma.Web.ActivityPub.ActivityPub do
  alias Pleroma.Repo
  alias Pleroma.Activity
  import Ecto.Query

  def insert(map) when is_map(map) do
    Repo.insert(%Activity{data: map})
  end

  def fetch_public_activities do
    query = from activity in Activity,
      where: fragment(~s(? @> '{"to": ["https://www.w3.org/ns/activitystreams#Public"]}'), activity.data),
      limit: 20,
      order_by: [desc: :inserted_at]

    Repo.all(query)
    |> Enum.reverse
  end
end
