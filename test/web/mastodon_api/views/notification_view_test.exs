# Pleroma: A lightweight social networking server
# Copyright © 2017-2020 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.MastodonAPI.NotificationViewTest do
  use Pleroma.DataCase

  alias Pleroma.Activity
  alias Pleroma.Chat
  alias Pleroma.Notification
  alias Pleroma.Object
  alias Pleroma.Repo
  alias Pleroma.User
  alias Pleroma.Web.CommonAPI
  alias Pleroma.Web.CommonAPI.Utils
  alias Pleroma.Web.MastodonAPI.AccountView
  alias Pleroma.Web.MastodonAPI.NotificationView
  alias Pleroma.Web.MastodonAPI.StatusView
  alias Pleroma.Web.PleromaAPI.ChatMessageView
  import Pleroma.Factory

  defp test_notifications_rendering(notifications, user, expected_result) do
    result = NotificationView.render("index.json", %{notifications: notifications, for: user})

    assert expected_result == result

    result =
      NotificationView.render("index.json", %{
        notifications: notifications,
        for: user,
        relationships: nil
      })

    assert expected_result == result
  end

  test "ChatMessage notification" do
    user = insert(:user)
    recipient = insert(:user)
    {:ok, activity} = CommonAPI.post_chat_message(user, recipient, "what's up my dude")

    {:ok, [notification]} = Notification.create_notifications(activity)

    object = Object.normalize(activity)
    chat = Chat.get(recipient.id, user.ap_id)

    expected = %{
      id: to_string(notification.id),
      pleroma: %{is_seen: false},
      type: "pleroma:chat_mention",
      account: AccountView.render("show.json", %{user: user, for: recipient}),
      chat_message:
        ChatMessageView.render("show.json", %{object: object, for: recipient, chat: chat}),
      created_at: Utils.to_masto_date(notification.inserted_at)
    }

    test_notifications_rendering([notification], recipient, [expected])
  end

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

    test_notifications_rendering([notification], mentioned_user, [expected])
  end

  test "Favourite notification" do
    user = insert(:user)
    another_user = insert(:user)
    {:ok, create_activity} = CommonAPI.post(user, %{"status" => "hey"})
    {:ok, favorite_activity} = CommonAPI.favorite(another_user, create_activity.id)
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

    test_notifications_rendering([notification], user, [expected])
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

    test_notifications_rendering([notification], user, [expected])
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

    test_notifications_rendering([notification], followed, [expected])

    User.perform(:delete, follower)
    notification = Notification |> Repo.one() |> Repo.preload(:activity)

    test_notifications_rendering([notification], followed, [])
  end

  @tag capture_log: true
  test "Move notification" do
    old_user = insert(:user)
    new_user = insert(:user, also_known_as: [old_user.ap_id])
    follower = insert(:user)

    old_user_url = old_user.ap_id

    body =
      File.read!("test/fixtures/users_mock/localhost.json")
      |> String.replace("{{nickname}}", old_user.nickname)
      |> Jason.encode!()

    Tesla.Mock.mock(fn
      %{method: :get, url: ^old_user_url} ->
        %Tesla.Env{status: 200, body: body}
    end)

    User.follow(follower, old_user)
    Pleroma.Web.ActivityPub.ActivityPub.move(old_user, new_user)
    Pleroma.Tests.ObanHelpers.perform_all()

    old_user = refresh_record(old_user)
    new_user = refresh_record(new_user)

    [notification] = Notification.for_user(follower)

    expected = %{
      id: to_string(notification.id),
      pleroma: %{is_seen: false},
      type: "move",
      account: AccountView.render("show.json", %{user: old_user, for: follower}),
      target: AccountView.render("show.json", %{user: new_user, for: follower}),
      created_at: Utils.to_masto_date(notification.inserted_at)
    }

    test_notifications_rendering([notification], follower, [expected])
  end

  test "EmojiReact notification" do
    user = insert(:user)
    other_user = insert(:user)

    {:ok, activity} = CommonAPI.post(user, %{"status" => "#cofe"})
    {:ok, _activity} = CommonAPI.react_with_emoji(activity.id, other_user, "☕")

    activity = Repo.get(Activity, activity.id)

    [notification] = Notification.for_user(user)

    assert notification

    expected = %{
      id: to_string(notification.id),
      pleroma: %{is_seen: false},
      type: "pleroma:emoji_reaction",
      emoji: "☕",
      account: AccountView.render("show.json", %{user: other_user, for: user}),
      status: StatusView.render("show.json", %{activity: activity, for: user}),
      created_at: Utils.to_masto_date(notification.inserted_at)
    }

    test_notifications_rendering([notification], user, [expected])
  end
end
