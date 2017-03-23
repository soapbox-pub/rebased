defmodule Pleroma.Web.TwitterAPI.TwitterAPI do
  alias Pleroma.User
  alias Pleroma.Web.ActivityPub.ActivityPub
  alias Pleroma.Repo
  alias Pleroma.Web.TwitterAPI.Representers.ActivityRepresenter

  def create_status(user = %User{}, data = %{}) do
    date = DateTime.utc_now() |> DateTime.to_iso8601
    activity = %{
      "type" => "Create",
      "to" => [
        User.ap_followers(user),
        "https://www.w3.org/ns/activitystreams#Public"
      ],
      "actor" => User.ap_id(user),
      "object" => %{
        "type" => "Note",
        "content" => data["status"],
        "published" => date
      },
      "published" => date
    }

    ActivityPub.insert(activity)
  end

  def fetch_friend_statuses(user, opts \\ %{}) do
    ActivityPub.fetch_activities(user.following, opts)
    |> activities_to_statuses(%{for: user})
  end

  def fetch_public_statuses(user, opts \\ %{}) do
    ActivityPub.fetch_public_activities(opts)
    |> activities_to_statuses(%{for: user})
  end

  def follow(%User{} = follower, followed_id) do
    with %User{} = followed <- Repo.get(User, followed_id),
         { :ok, follower } <- User.follow(follower, followed)
    do
      { :ok, follower, followed }
    end
  end

  def unfollow(%User{} = follower, followed_id) do
    with %User{} = followed <- Repo.get(User, followed_id),
         { :ok, follower } <- User.unfollow(follower, followed)
    do
      { :ok, follower, followed }
    end
  end

  defp activities_to_statuses(activities, opts) do
    Enum.map(activities, fn(activity) ->
      actor = get_in(activity.data, ["actor"])
      user = Repo.get_by!(User, ap_id: actor)
      ActivityRepresenter.to_map(activity, Map.merge(opts, %{user: user}))
    end)
  end
end
