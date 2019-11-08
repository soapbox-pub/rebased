# Pleroma: A lightweight social networking server
# Copyright © 2017-2019 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.MastodonAPI.MastodonAPITest do
  use Pleroma.Web.ConnCase

  alias Pleroma.Notification
  alias Pleroma.ScheduledActivity
  alias Pleroma.User
  alias Pleroma.Web.CommonAPI
  alias Pleroma.Web.MastodonAPI.MastodonAPI

  import Pleroma.Factory

  describe "follow/3" do
    test "returns error when followed user is deactivated" do
      follower = insert(:user)
      user = insert(:user, local: true, deactivated: true)
      {:error, error} = MastodonAPI.follow(follower, user)
      assert error == "Could not follow user: #{user.nickname} is deactivated."
    end

    test "following for user" do
      follower = insert(:user)
      user = insert(:user)
      {:ok, follower} = MastodonAPI.follow(follower, user)
      assert User.following?(follower, user)
    end

    test "returns ok if user already followed" do
      follower = insert(:user)
      user = insert(:user)
      {:ok, follower} = User.follow(follower, user)
      {:ok, follower} = MastodonAPI.follow(follower, refresh_record(user))
      assert User.following?(follower, user)
    end
  end

  describe "get_followers/2" do
    test "returns user followers" do
      follower1_user = insert(:user)
      follower2_user = insert(:user)
      user = insert(:user)
      {:ok, _follower1_user} = User.follow(follower1_user, user)
      {:ok, follower2_user} = User.follow(follower2_user, user)

      assert MastodonAPI.get_followers(user, %{"limit" => 1}) == [follower2_user]
    end
  end

  describe "get_friends/2" do
    test "returns user friends" do
      user = insert(:user)
      followed_one = insert(:user)
      followed_two = insert(:user)
      followed_three = insert(:user)

      {:ok, user} = User.follow(user, followed_one)
      {:ok, user} = User.follow(user, followed_two)
      {:ok, user} = User.follow(user, followed_three)
      res = MastodonAPI.get_friends(user)

      assert length(res) == 3
      assert Enum.member?(res, refresh_record(followed_three))
      assert Enum.member?(res, refresh_record(followed_two))
      assert Enum.member?(res, refresh_record(followed_one))
    end
  end

  describe "get_notifications/2" do
    test "returns notifications for user" do
      user = insert(:user)
      subscriber = insert(:user)

      User.subscribe(subscriber, user)

      {:ok, status} = CommonAPI.post(user, %{"status" => "Akariiiin"})

      {:ok, status1} = CommonAPI.post(user, %{"status" => "Magi"})
      {:ok, [notification]} = Notification.create_notifications(status)
      {:ok, [notification1]} = Notification.create_notifications(status1)
      res = MastodonAPI.get_notifications(subscriber)

      assert Enum.member?(Enum.map(res, & &1.id), notification.id)
      assert Enum.member?(Enum.map(res, & &1.id), notification1.id)
    end
  end

  describe "get_scheduled_activities/2" do
    test "returns user scheduled activities" do
      user = insert(:user)

      today =
        NaiveDateTime.utc_now()
        |> NaiveDateTime.add(:timer.minutes(6), :millisecond)
        |> NaiveDateTime.to_iso8601()

      attrs = %{params: %{}, scheduled_at: today}
      {:ok, schedule} = ScheduledActivity.create(user, attrs)
      assert MastodonAPI.get_scheduled_activities(user) == [schedule]
    end
  end
end
