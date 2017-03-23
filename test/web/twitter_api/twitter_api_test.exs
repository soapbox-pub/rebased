defmodule Pleroma.Web.TwitterAPI.TwitterAPITest do
  use Pleroma.DataCase
  alias Pleroma.Builders.{UserBuilder, ActivityBuilder}
  alias Pleroma.Web.TwitterAPI.TwitterAPI
  alias Pleroma.{Activity, User}
  alias Pleroma.Web.TwitterAPI.Representers.ActivityRepresenter

  test "create a status" do
    user = UserBuilder.build
    input = %{
      "status" => "Hello again."
    }

    { :ok, activity = %Activity{} } = TwitterAPI.create_status(user, input)

    assert get_in(activity.data, ["object", "content"]) == "Hello again."
    assert get_in(activity.data, ["object", "type"]) == "Note"
    assert get_in(activity.data, ["actor"]) == User.ap_id(user)
    assert Enum.member?(get_in(activity.data, ["to"]), User.ap_followers(user))
    assert Enum.member?(get_in(activity.data, ["to"]), "https://www.w3.org/ns/activitystreams#Public")
  end

  test "fetch public statuses" do
    %{ public: activity, user: user } = ActivityBuilder.public_and_non_public
    {:ok, follower } = UserBuilder.insert(%{name: "dude", ap_id: "idididid", following: [User.ap_followers(user)]})

    statuses = TwitterAPI.fetch_public_statuses(follower)

    assert length(statuses) == 1
    assert Enum.at(statuses, 0) == ActivityRepresenter.to_map(activity, %{user: user, for: follower})
  end

  test "fetch friends' statuses" do
    ActivityBuilder.public_and_non_public
    {:ok, activity} = ActivityBuilder.insert(%{"to" => ["someguy/followers"]})
    {:ok, user} = UserBuilder.insert(%{ap_id: "some other id", following: ["someguy/followers"]})

    statuses = TwitterAPI.fetch_friend_statuses(user)

    activity_user = Repo.get_by(User, ap_id: activity.data["actor"])

    assert length(statuses) == 1
    assert Enum.at(statuses, 0) == ActivityRepresenter.to_map(activity, %{user: activity_user})
  end

  test "Follow another user" do
    { :ok, user } = UserBuilder.insert
    { :ok, following } = UserBuilder.insert(%{nickname: "guy"})

    {:ok, user, following } = TwitterAPI.follow(user, following.id)

    user = Repo.get(User, user.id)

    assert user.following == [User.ap_followers(following)]
  end

  test "Unfollow another user" do
    { :ok, following } = UserBuilder.insert(%{nickname: "guy"})
    { :ok, user } = UserBuilder.insert(%{following: [User.ap_followers(following)]})

    {:ok, user, _following } = TwitterAPI.unfollow(user, following.id)

    user = Repo.get(User, user.id)

    assert user.following == []
  end
end
