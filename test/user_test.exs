defmodule Pleroma.UserTest do
  alias Pleroma.Builders.UserBuilder
  alias Pleroma.User
  use Pleroma.DataCase

  import Pleroma.Factory

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
    user = insert(:user)
    followed = insert(:user)

    {:ok, user } = User.follow(user, followed)

    user = Repo.get(User, user.id)

    assert user.following == [User.ap_followers(followed)]
  end

  test "unfollow takes a user and another user" do
    followed = insert(:user)
    user = insert(:user, %{following: [User.ap_followers(followed)]})

    {:ok, user } = User.unfollow(user, followed)

    user = Repo.get(User, user.id)

    assert user.following == []
  end

  test "test if a user is following another user" do
    followed = insert(:user)
    user = insert(:user, %{following: [User.ap_followers(followed)]})

    assert User.following?(user, followed)
    refute User.following?(followed, user)
  end

  describe "user registration" do
    @full_user_data %{
      bio: "A guy",
      name: "my name",
      nickname: "nick",
      password: "test",
      password_confirmation: "test",
      email: "email@example.com"
    }

    test "it requires a bio, email, name, nickname and password" do
      @full_user_data
      |> Map.keys
      |> Enum.each(fn (key) ->
        params = Map.delete(@full_user_data, key)
        changeset = User.register_changeset(%User{}, params)
        assert changeset.valid? == false
      end)
    end

    test "it sets the password_hash, ap_id and following fields" do
      changeset = User.register_changeset(%User{}, @full_user_data)

      assert changeset.valid?

      assert is_binary(changeset.changes[:password_hash])
      assert changeset.changes[:ap_id] == User.ap_id(%User{nickname: @full_user_data.nickname})
      assert changeset.changes[:following] == [User.ap_followers(%User{nickname: @full_user_data.nickname})]
    end
  end
end
