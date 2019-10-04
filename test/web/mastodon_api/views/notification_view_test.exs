# Pleroma: A lightweight social networking server
# Copyright © 2017-2019 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.MastodonAPI.NotificationViewTest do
  use Pleroma.DataCase

  alias Pleroma.Activity
  alias Pleroma.Notification
  alias Pleroma.Repo
  alias Pleroma.User
  alias Pleroma.Web.CommonAPI
  alias Pleroma.Web.CommonAPI.Utils
  alias Pleroma.Web.MastodonAPI.AccountView
  alias Pleroma.Web.MastodonAPI.NotificationView
  alias Pleroma.Web.MastodonAPI.StatusView
  import Pleroma.Factory

  test "Mention notification" do
    user = insert(:user)
    mentioned_user = insert(:user)
    {:ok, activity} = CommonAPI.post(user, %{"status" => "hey @#{mentioned_user.nickname}"})
    {:ok, [notification]} = Notification.create_notifications(activity)
    user = User.get_cached_by_id(user.id)

    expected = %{
      id: to_string(notification.id),
      pleroma: %{is_seen: false},
      type: "mention",
      account: AccountView.render("show.json", %{user: user, for: mentioned_user}),
      status: StatusView.render("show.json", %{activity: activity, for: mentioned_user}),
      created_at: Utils.to_masto_date(notification.inserted_at)
    }

    result =
      NotificationView.render("index.json", %{notifications: [notification], for: mentioned_user})

    assert [expected] == result
  end

  test "Favourite notification" do
    user = insert(:user)
    another_user = insert(:user)
    {:ok, create_activity} = CommonAPI.post(user, %{"status" => "hey"})
    {:ok, favorite_activity, _object} = CommonAPI.favorite(create_activity.id, another_user)
    {:ok, [notification]} = Notification.create_notifications(favorite_activity)
    create_activity = Activity.get_by_id(create_activity.id)

    expected = %{
      id: to_string(notification.id),
      pleroma: %{is_seen: false},
      type: "favourite",
      account: AccountView.render("show.json", %{user: another_user, for: user}),
      status: StatusView.render("show.json", %{activity: create_activity, for: user}),
      created_at: Utils.to_masto_date(notification.inserted_at)
    }

    result = NotificationView.render("index.json", %{notifications: [notification], for: user})

    assert [expected] == result
  end

  test "Reblog notification" do
    user = insert(:user)
    another_user = insert(:user)
    {:ok, create_activity} = CommonAPI.post(user, %{"status" => "hey"})
    {:ok, reblog_activity, _object} = CommonAPI.repeat(create_activity.id, another_user)
    {:ok, [notification]} = Notification.create_notifications(reblog_activity)
    reblog_activity = Activity.get_by_id(create_activity.id)

    expected = %{
      id: to_string(notification.id),
      pleroma: %{is_seen: false},
      type: "reblog",
      account: AccountView.render("show.json", %{user: another_user, for: user}),
      status: StatusView.render("show.json", %{activity: reblog_activity, for: user}),
      created_at: Utils.to_masto_date(notification.inserted_at)
    }

    result = NotificationView.render("index.json", %{notifications: [notification], for: user})

    assert [expected] == result
  end

  test "Follow notification" do
    follower = insert(:user)
    followed = insert(:user)
    {:ok, follower, followed, _activity} = CommonAPI.follow(follower, followed)
    notification = Notification |> Repo.one() |> Repo.preload(:activity)

    expected = %{
      id: to_string(notification.id),
      pleroma: %{is_seen: false},
      type: "follow",
      account: AccountView.render("show.json", %{user: follower, for: followed}),
      created_at: Utils.to_masto_date(notification.inserted_at)
    }

    result =
      NotificationView.render("index.json", %{notifications: [notification], for: followed})

    assert [expected] == result

    User.perform(:delete, follower)
    notification = Notification |> Repo.one() |> Repo.preload(:activity)

    assert [] ==
             NotificationView.render("index.json", %{notifications: [notification], for: followed})
  end
end
