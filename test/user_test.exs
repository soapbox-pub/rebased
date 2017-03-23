defmodule Pleroma.UserTest do
  alias Pleroma.Builders.UserBuilder
  alias Pleroma.User
  use Pleroma.DataCase

  test "ap_id returns the activity pub id for the user" do
    host =
      Application.get_env(:pleroma, Pleroma.Web.Endpoint)
      |> Keyword.fetch!(:url)
      |> Keyword.fetch!(:host)

    user = UserBuilder.build

    expected_ap_id = "https://#{host}/users/#{user.nickname}"

    assert expected_ap_id == User.ap_id(user)
  end

  test "ap_followers returns the followers collection for the user" do
    user = UserBuilder.build

    expected_followers_collection = "#{User.ap_id(user)}/followers"

    assert expected_followers_collection == User.ap_followers(user)
  end

  test "follow takes a user and another user" do
    { :ok, user } = UserBuilder.insert
    { :ok, following } = UserBuilder.insert(%{nickname: "guy"})

    {:ok, user } = User.follow(user, following)

    user = Repo.get(User, user.id)

    assert user.following == [User.ap_followers(following)]
  end

  test "unfollow takes a user and another user" do
    { :ok, following } = UserBuilder.insert(%{nickname: "guy"})
    { :ok, user } = UserBuilder.insert(%{following: [User.ap_followers(following)]})

    {:ok, user } = User.unfollow(user, following)

    user = Repo.get(User, user.id)

    assert user.following == []
  end
end
