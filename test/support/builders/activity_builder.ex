defmodule Pleroma.Builders.ActivityBuilder do
  alias Pleroma.Web.ActivityPub.ActivityPub

  def build(data \\ %{}, opts \\ %{}) do
    user = opts[:user] || Pleroma.Factory.insert(:user)

    activity = %{
      "id" => Pleroma.Web.ActivityPub.Utils.generate_object_id(),
      "actor" => user.ap_id,
      "to" => ["https://www.w3.org/ns/activitystreams#Public"],
      "type" => "Create",
      "object" => %{
        "type" => "Note",
        "content" => "test",
        "to" => ["https://www.w3.org/ns/activitystreams#Public"]
      }
    }

    Map.merge(activity, data)
  end

  def insert(data \\ %{}, opts \\ %{}) do
    activity = build(data, opts)
    ActivityPub.insert(activity)
  end

  def insert_list(times, data \\ %{}, opts \\ %{}) do
    Enum.map(1..times, fn _n ->
      {:ok, activity} = insert(data, opts)
      activity
    end)
  end

  def public_and_non_public do
    user = Pleroma.Factory.insert(:user)

    public = build(%{"id" => 1}, %{user: user})
    non_public = build(%{"id" => 2, "to" => [user.follower_address]}, %{user: user})

    {:ok, public} = ActivityPub.insert(public)
    {:ok, non_public} = ActivityPub.insert(non_public)

    %{
      public: public,
      non_public: non_public,
      user: user
    }
  end
end
