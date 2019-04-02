# Pleroma: A lightweight social networking server
# Copyright © 2017-2018 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.TwitterAPI.NotificationViewTest do
  use Pleroma.DataCase

  alias Pleroma.Notification
  alias Pleroma.User
  alias Pleroma.Web.ActivityPub.ActivityPub
  alias Pleroma.Web.CommonAPI.Utils
  alias Pleroma.Web.TwitterAPI.ActivityView
  alias Pleroma.Web.TwitterAPI.NotificationView
  alias Pleroma.Web.TwitterAPI.TwitterAPI
  alias Pleroma.Web.TwitterAPI.UserView

  import Pleroma.Factory

  setup do
    user = insert(:user, bio: "<span>Here's some html</span>")
    [user: user]
  end

  test "A follow notification" do
    note_activity = insert(:note_activity)
    user = User.get_cached_by_ap_id(note_activity.data["actor"])
    follower = insert(:user)

    {:ok, follower} = User.follow(follower, user)
    {:ok, activity} = ActivityPub.follow(follower, user)
    Cachex.put(:user_cache, "user_info:#{user.id}", User.user_info(Repo.get!(User, user.id)))
    [follow_notif] = Notification.for_user(user)

    represented = %{
      "created_at" => follow_notif.inserted_at |> Utils.format_naive_asctime(),
      "from_profile" => UserView.render("show.json", %{user: follower, for: user}),
      "id" => follow_notif.id,
      "is_seen" => 0,
      "notice" => ActivityView.render("activity.json", %{activity: activity, for: user}),
      "ntype" => "follow"
    }

    assert represented ==
             NotificationView.render("notification.json", %{notification: follow_notif, for: user})
  end

  test "A mention notification" do
    user = insert(:user)
    other_user = insert(:user)

    {:ok, activity} =
      TwitterAPI.create_status(other_user, %{"status" => "Päivää, @#{user.nickname}"})

    [notification] = Notification.for_user(user)

    represented = %{
      "created_at" => notification.inserted_at |> Utils.format_naive_asctime(),
      "from_profile" => UserView.render("show.json", %{user: other_user, for: user}),
      "id" => notification.id,
      "is_seen" => 0,
      "notice" => ActivityView.render("activity.json", %{activity: activity, for: user}),
      "ntype" => "mention"
    }

    assert represented ==
             NotificationView.render("notification.json", %{notification: notification, for: user})
  end

  test "A retweet notification" do
    note_activity = insert(:note_activity)
    user = User.get_cached_by_ap_id(note_activity.data["actor"])
    repeater = insert(:user)

    {:ok, _activity} = TwitterAPI.repeat(repeater, note_activity.id)
    [notification] = Notification.for_user(user)

    represented = %{
      "created_at" => notification.inserted_at |> Utils.format_naive_asctime(),
      "from_profile" => UserView.render("show.json", %{user: repeater, for: user}),
      "id" => notification.id,
      "is_seen" => 0,
      "notice" =>
        ActivityView.render("activity.json", %{activity: notification.activity, for: user}),
      "ntype" => "repeat"
    }

    assert represented ==
             NotificationView.render("notification.json", %{notification: notification, for: user})
  end

  test "A like notification" do
    note_activity = insert(:note_activity)
    user = User.get_cached_by_ap_id(note_activity.data["actor"])
    liker = insert(:user)

    {:ok, _activity} = TwitterAPI.fav(liker, note_activity.id)
    [notification] = Notification.for_user(user)

    represented = %{
      "created_at" => notification.inserted_at |> Utils.format_naive_asctime(),
      "from_profile" => UserView.render("show.json", %{user: liker, for: user}),
      "id" => notification.id,
      "is_seen" => 0,
      "notice" =>
        ActivityView.render("activity.json", %{activity: notification.activity, for: user}),
      "ntype" => "like"
    }

    assert represented ==
             NotificationView.render("notification.json", %{notification: notification, for: user})
  end
end
