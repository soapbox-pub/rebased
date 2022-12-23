# Pleroma: A lightweight social networking server
# Copyright © 2017-2022 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.MastodonAPI.NotificationViewTest do
  use Pleroma.DataCase, async: false

  alias Pleroma.Activity
  alias Pleroma.Chat
  alias Pleroma.Chat.MessageReference
  alias Pleroma.Notification
  alias Pleroma.Object
  alias Pleroma.Repo
  alias Pleroma.User
  alias Pleroma.Web.AdminAPI.Report
  alias Pleroma.Web.AdminAPI.ReportView
  alias Pleroma.Web.CommonAPI
  alias Pleroma.Web.CommonAPI.Utils
  alias Pleroma.Web.MastodonAPI.AccountView
  alias Pleroma.Web.MastodonAPI.NotificationView
  alias Pleroma.Web.MastodonAPI.StatusView
  alias Pleroma.Web.PleromaAPI.Chat.MessageReferenceView
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

    object = Object.normalize(activity, fetch: false)
    chat = Chat.get(recipient.id, user.ap_id)

    cm_ref = MessageReference.for_chat_and_object(chat, object)

    expected = %{
      id: to_string(notification.id),
      pleroma: %{is_seen: false, is_muted: false},
      type: "pleroma:chat_mention",
      account: AccountView.render("show.json", %{user: user, for: recipient}),
      chat_message: MessageReferenceView.render("show.json", %{chat_message_reference: cm_ref}),
      created_at: Utils.to_masto_date(notification.inserted_at)
    }

    test_notifications_rendering([notification], recipient, [expected])
  end

  test "Mention notification" do
    user = insert(:user)
    mentioned_user = insert(:user)
    {:ok, activity} = CommonAPI.post(user, %{status: "hey @#{mentioned_user.nickname}"})
    {:ok, [notification]} = Notification.create_notifications(activity)
    user = User.get_cached_by_id(user.id)

    expected = %{
      id: to_string(notification.id),
      pleroma: %{is_seen: false, is_muted: false},
      type: "mention",
      account:
        AccountView.render("show.json", %{
          user: user,
          for: mentioned_user
        }),
      status: StatusView.render("show.json", %{activity: activity, for: mentioned_user}),
      created_at: Utils.to_masto_date(notification.inserted_at)
    }

    test_notifications_rendering([notification], mentioned_user, [expected])
  end

  test "Favourite notification" do
    user = insert(:user)
    another_user = insert(:user)
    {:ok, create_activity} = CommonAPI.post(user, %{status: "hey"})
    {:ok, favorite_activity} = CommonAPI.favorite(another_user, create_activity.id)
    {:ok, [notification]} = Notification.create_notifications(favorite_activity)
    create_activity = Activity.get_by_id(create_activity.id)

    expected = %{
      id: to_string(notification.id),
      pleroma: %{is_seen: false, is_muted: false},
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
    {:ok, create_activity} = CommonAPI.post(user, %{status: "hey"})
    {:ok, reblog_activity} = CommonAPI.repeat(create_activity.id, another_user)
    {:ok, [notification]} = Notification.create_notifications(reblog_activity)
    reblog_activity = Activity.get_by_id(create_activity.id)

    expected = %{
      id: to_string(notification.id),
      pleroma: %{is_seen: false, is_muted: false},
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
      pleroma: %{is_seen: false, is_muted: false},
      type: "follow",
      account: AccountView.render("show.json", %{user: follower, for: followed}),
      created_at: Utils.to_masto_date(notification.inserted_at)
    }

    test_notifications_rendering([notification], followed, [expected])

    User.perform(:delete, follower)
    refute Repo.one(Notification)
  end

  test "Move notification" do
    old_user = insert(:user)
    new_user = insert(:user, also_known_as: [old_user.ap_id])
    follower = insert(:user)

    User.follow(follower, old_user)
    Pleroma.Web.ActivityPub.ActivityPub.move(old_user, new_user)
    Pleroma.Tests.ObanHelpers.perform_all()

    old_user = refresh_record(old_user)
    new_user = refresh_record(new_user)

    [notification] = Notification.for_user(follower)

    expected = %{
      id: to_string(notification.id),
      pleroma: %{is_seen: false, is_muted: false},
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

    {:ok, activity} = CommonAPI.post(user, %{status: "#cofe"})
    {:ok, _activity} = CommonAPI.react_with_emoji(activity.id, other_user, "☕")

    activity = Repo.get(Activity, activity.id)

    [notification] = Notification.for_user(user)

    assert notification

    expected = %{
      id: to_string(notification.id),
      pleroma: %{is_seen: false, is_muted: false},
      type: "pleroma:emoji_reaction",
      emoji: "☕",
      account: AccountView.render("show.json", %{user: other_user, for: user}),
      status: StatusView.render("show.json", %{activity: activity, for: user}),
      created_at: Utils.to_masto_date(notification.inserted_at)
    }

    test_notifications_rendering([notification], user, [expected])
  end

  test "Poll notification" do
    user = insert(:user)
    activity = insert(:question_activity, user: user)
    {:ok, [notification]} = Notification.create_poll_notifications(activity)

    expected = %{
      id: to_string(notification.id),
      pleroma: %{is_seen: false, is_muted: false},
      type: "poll",
      account:
        AccountView.render("show.json", %{
          user: user,
          for: user
        }),
      status: StatusView.render("show.json", %{activity: activity, for: user}),
      created_at: Utils.to_masto_date(notification.inserted_at)
    }

    test_notifications_rendering([notification], user, [expected])
  end

  test "Report notification" do
    clear_config([:instance, :moderator_privileges], [:reports_manage_reports])

    reporting_user = insert(:user)
    reported_user = insert(:user)
    moderator_user = insert(:user, is_moderator: true)

    {:ok, activity} = CommonAPI.report(reporting_user, %{account_id: reported_user.id})
    {:ok, [notification]} = Notification.create_notifications(activity)

    expected = %{
      id: to_string(notification.id),
      pleroma: %{is_seen: false, is_muted: false},
      type: "pleroma:report",
      account: AccountView.render("show.json", %{user: reporting_user, for: moderator_user}),
      created_at: Utils.to_masto_date(notification.inserted_at),
      report: ReportView.render("show.json", Report.extract_report_info(activity))
    }

    test_notifications_rendering([notification], moderator_user, [expected])
  end

  test "Edit notification" do
    user = insert(:user)
    repeat_user = insert(:user)

    {:ok, activity} = CommonAPI.post(user, %{status: "mew"})
    {:ok, _} = CommonAPI.repeat(activity.id, repeat_user)
    {:ok, update} = CommonAPI.update(user, activity, %{status: "mew mew"})

    user = Pleroma.User.get_by_ap_id(user.ap_id)
    activity = Pleroma.Activity.normalize(activity)
    update = Pleroma.Activity.normalize(update)

    {:ok, [notification]} = Notification.create_notifications(update)

    expected = %{
      id: to_string(notification.id),
      pleroma: %{is_seen: false, is_muted: false},
      type: "update",
      account: AccountView.render("show.json", %{user: user, for: repeat_user}),
      created_at: Utils.to_masto_date(notification.inserted_at),
      status: StatusView.render("show.json", %{activity: activity, for: repeat_user})
    }

    test_notifications_rendering([notification], repeat_user, [expected])
  end

  test "muted notification" do
    user = insert(:user)
    another_user = insert(:user)

    {:ok, _} = Pleroma.UserRelationship.create_mute(user, another_user)
    {:ok, create_activity} = CommonAPI.post(user, %{status: "hey"})
    {:ok, favorite_activity} = CommonAPI.favorite(another_user, create_activity.id)
    {:ok, [notification]} = Notification.create_notifications(favorite_activity)
    create_activity = Activity.get_by_id(create_activity.id)

    expected = %{
      id: to_string(notification.id),
      pleroma: %{is_seen: true, is_muted: true},
      type: "favourite",
      account: AccountView.render("show.json", %{user: another_user, for: user}),
      status: StatusView.render("show.json", %{activity: create_activity, for: user}),
      created_at: Utils.to_masto_date(notification.inserted_at)
    }

    test_notifications_rendering([notification], user, [expected])
  end
end
