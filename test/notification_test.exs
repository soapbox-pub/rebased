# Pleroma: A lightweight social networking server
# Copyright © 2017-2019 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.NotificationTest do
  use Pleroma.DataCase

  import Pleroma.Factory

  alias Pleroma.Notification
  alias Pleroma.Tests.ObanHelpers
  alias Pleroma.User
  alias Pleroma.Web.ActivityPub.Transmogrifier
  alias Pleroma.Web.CommonAPI
  alias Pleroma.Web.Streamer

  describe "create_notifications" do
    test "creates a notification for an emoji reaction" do
      user = insert(:user)
      other_user = insert(:user)

      {:ok, activity} = CommonAPI.post(user, %{"status" => "yeah"})
      {:ok, activity, _object} = CommonAPI.react_with_emoji(activity.id, other_user, "☕")

      {:ok, [notification]} = Notification.create_notifications(activity)

      assert notification.user_id == user.id
    end

    test "notifies someone when they are directly addressed" do
      user = insert(:user)
      other_user = insert(:user)
      third_user = insert(:user)

      {:ok, activity} =
        CommonAPI.post(user, %{
          "status" => "hey @#{other_user.nickname} and @#{third_user.nickname}"
        })

      {:ok, [notification, other_notification]} = Notification.create_notifications(activity)

      notified_ids = Enum.sort([notification.user_id, other_notification.user_id])
      assert notified_ids == [other_user.id, third_user.id]
      assert notification.activity_id == activity.id
      assert other_notification.activity_id == activity.id
    end

    test "it creates a notification for subscribed users" do
      user = insert(:user)
      subscriber = insert(:user)

      User.subscribe(subscriber, user)

      {:ok, status} = CommonAPI.post(user, %{"status" => "Akariiiin"})
      {:ok, [notification]} = Notification.create_notifications(status)

      assert notification.user_id == subscriber.id
    end

    test "does not create a notification for subscribed users if status is a reply" do
      user = insert(:user)
      other_user = insert(:user)
      subscriber = insert(:user)

      User.subscribe(subscriber, other_user)

      {:ok, activity} = CommonAPI.post(user, %{"status" => "test post"})

      {:ok, _reply_activity} =
        CommonAPI.post(other_user, %{
          "status" => "test reply",
          "in_reply_to_status_id" => activity.id
        })

      user_notifications = Notification.for_user(user)
      assert length(user_notifications) == 1

      subscriber_notifications = Notification.for_user(subscriber)
      assert Enum.empty?(subscriber_notifications)
    end
  end

  describe "create_notification" do
    @tag needs_streamer: true
    test "it creates a notification for user and send to the 'user' and the 'user:notification' stream" do
      user = insert(:user)
      task = Task.async(fn -> assert_receive {:text, _}, 4_000 end)
      task_user_notification = Task.async(fn -> assert_receive {:text, _}, 4_000 end)
      Streamer.add_socket("user", %{transport_pid: task.pid, assigns: %{user: user}})

      Streamer.add_socket(
        "user:notification",
        %{transport_pid: task_user_notification.pid, assigns: %{user: user}}
      )

      activity = insert(:note_activity)

      notify = Notification.create_notification(activity, user)
      assert notify.user_id == user.id
      Task.await(task)
      Task.await(task_user_notification)
    end

    test "it creates a notification for user if the user blocks the activity author" do
      activity = insert(:note_activity)
      author = User.get_cached_by_ap_id(activity.data["actor"])
      user = insert(:user)
      {:ok, _user_relationship} = User.block(user, author)

      assert Notification.create_notification(activity, user)
    end

    test "it creates a notification for the user if the user mutes the activity author" do
      muter = insert(:user)
      muted = insert(:user)
      {:ok, _} = User.mute(muter, muted)
      muter = Repo.get(User, muter.id)
      {:ok, activity} = CommonAPI.post(muted, %{"status" => "Hi @#{muter.nickname}"})

      assert Notification.create_notification(activity, muter)
    end

    test "notification created if user is muted without notifications" do
      muter = insert(:user)
      muted = insert(:user)

      {:ok, _user_relationships} = User.mute(muter, muted, false)

      {:ok, activity} = CommonAPI.post(muted, %{"status" => "Hi @#{muter.nickname}"})

      assert Notification.create_notification(activity, muter)
    end

    test "it creates a notification for an activity from a muted thread" do
      muter = insert(:user)
      other_user = insert(:user)
      {:ok, activity} = CommonAPI.post(muter, %{"status" => "hey"})
      CommonAPI.add_mute(muter, activity)

      {:ok, activity} =
        CommonAPI.post(other_user, %{
          "status" => "Hi @#{muter.nickname}",
          "in_reply_to_status_id" => activity.id
        })

      assert Notification.create_notification(activity, muter)
    end

    test "it disables notifications from followers" do
      follower = insert(:user)

      followed =
        insert(:user, notification_settings: %Pleroma.User.NotificationSetting{followers: false})

      User.follow(follower, followed)
      {:ok, activity} = CommonAPI.post(follower, %{"status" => "hey @#{followed.nickname}"})
      refute Notification.create_notification(activity, followed)
    end

    test "it disables notifications from non-followers" do
      follower = insert(:user)

      followed =
        insert(:user,
          notification_settings: %Pleroma.User.NotificationSetting{non_followers: false}
        )

      {:ok, activity} = CommonAPI.post(follower, %{"status" => "hey @#{followed.nickname}"})
      refute Notification.create_notification(activity, followed)
    end

    test "it disables notifications from people the user follows" do
      follower =
        insert(:user, notification_settings: %Pleroma.User.NotificationSetting{follows: false})

      followed = insert(:user)
      User.follow(follower, followed)
      follower = Repo.get(User, follower.id)
      {:ok, activity} = CommonAPI.post(followed, %{"status" => "hey @#{follower.nickname}"})
      refute Notification.create_notification(activity, follower)
    end

    test "it disables notifications from people the user does not follow" do
      follower =
        insert(:user, notification_settings: %Pleroma.User.NotificationSetting{non_follows: false})

      followed = insert(:user)
      {:ok, activity} = CommonAPI.post(followed, %{"status" => "hey @#{follower.nickname}"})
      refute Notification.create_notification(activity, follower)
    end

    test "it doesn't create a notification for user if he is the activity author" do
      activity = insert(:note_activity)
      author = User.get_cached_by_ap_id(activity.data["actor"])

      refute Notification.create_notification(activity, author)
    end

    test "it doesn't create a notification for follow-unfollow-follow chains" do
      user = insert(:user)
      followed_user = insert(:user)
      {:ok, _, _, activity} = CommonAPI.follow(user, followed_user)
      Notification.create_notification(activity, followed_user)
      CommonAPI.unfollow(user, followed_user)
      {:ok, _, _, activity_dupe} = CommonAPI.follow(user, followed_user)
      refute Notification.create_notification(activity_dupe, followed_user)
    end

    test "it doesn't create duplicate notifications for follow+subscribed users" do
      user = insert(:user)
      subscriber = insert(:user)

      {:ok, _, _, _} = CommonAPI.follow(subscriber, user)
      User.subscribe(subscriber, user)
      {:ok, status} = CommonAPI.post(user, %{"status" => "Akariiiin"})
      {:ok, [_notif]} = Notification.create_notifications(status)
    end

    test "it doesn't create subscription notifications if the recipient cannot see the status" do
      user = insert(:user)
      subscriber = insert(:user)

      User.subscribe(subscriber, user)

      {:ok, status} = CommonAPI.post(user, %{"status" => "inwisible", "visibility" => "direct"})

      assert {:ok, []} == Notification.create_notifications(status)
    end
  end

  describe "get notification" do
    test "it gets a notification that belongs to the user" do
      user = insert(:user)
      other_user = insert(:user)

      {:ok, activity} = CommonAPI.post(user, %{"status" => "hey @#{other_user.nickname}"})

      {:ok, [notification]} = Notification.create_notifications(activity)
      {:ok, notification} = Notification.get(other_user, notification.id)

      assert notification.user_id == other_user.id
    end

    test "it returns error if the notification doesn't belong to the user" do
      user = insert(:user)
      other_user = insert(:user)

      {:ok, activity} = CommonAPI.post(user, %{"status" => "hey @#{other_user.nickname}"})

      {:ok, [notification]} = Notification.create_notifications(activity)
      {:error, _notification} = Notification.get(user, notification.id)
    end
  end

  describe "dismiss notification" do
    test "it dismisses a notification that belongs to the user" do
      user = insert(:user)
      other_user = insert(:user)

      {:ok, activity} = CommonAPI.post(user, %{"status" => "hey @#{other_user.nickname}"})

      {:ok, [notification]} = Notification.create_notifications(activity)
      {:ok, notification} = Notification.dismiss(other_user, notification.id)

      assert notification.user_id == other_user.id
    end

    test "it returns error if the notification doesn't belong to the user" do
      user = insert(:user)
      other_user = insert(:user)

      {:ok, activity} = CommonAPI.post(user, %{"status" => "hey @#{other_user.nickname}"})

      {:ok, [notification]} = Notification.create_notifications(activity)
      {:error, _notification} = Notification.dismiss(user, notification.id)
    end
  end

  describe "clear notification" do
    test "it clears all notifications belonging to the user" do
      user = insert(:user)
      other_user = insert(:user)
      third_user = insert(:user)

      {:ok, activity} =
        CommonAPI.post(user, %{
          "status" => "hey @#{other_user.nickname} and @#{third_user.nickname} !"
        })

      {:ok, _notifs} = Notification.create_notifications(activity)

      {:ok, activity} =
        CommonAPI.post(user, %{
          "status" => "hey again @#{other_user.nickname} and @#{third_user.nickname} !"
        })

      {:ok, _notifs} = Notification.create_notifications(activity)
      Notification.clear(other_user)

      assert Notification.for_user(other_user) == []
      assert Notification.for_user(third_user) != []
    end
  end

  describe "set_read_up_to()" do
    test "it sets all notifications as read up to a specified notification ID" do
      user = insert(:user)
      other_user = insert(:user)

      {:ok, _activity} =
        CommonAPI.post(user, %{
          "status" => "hey @#{other_user.nickname}!"
        })

      {:ok, _activity} =
        CommonAPI.post(user, %{
          "status" => "hey again @#{other_user.nickname}!"
        })

      [n2, n1] = notifs = Notification.for_user(other_user)
      assert length(notifs) == 2

      assert n2.id > n1.id

      {:ok, _activity} =
        CommonAPI.post(user, %{
          "status" => "hey yet again @#{other_user.nickname}!"
        })

      Notification.set_read_up_to(other_user, n2.id)

      [n3, n2, n1] = Notification.for_user(other_user)

      assert n1.seen == true
      assert n2.seen == true
      assert n3.seen == false
    end
  end

  describe "for_user_since/2" do
    defp days_ago(days) do
      NaiveDateTime.add(
        NaiveDateTime.truncate(NaiveDateTime.utc_now(), :second),
        -days * 60 * 60 * 24,
        :second
      )
    end

    test "Returns recent notifications" do
      user1 = insert(:user)
      user2 = insert(:user)

      Enum.each(0..10, fn i ->
        {:ok, _activity} =
          CommonAPI.post(user1, %{
            "status" => "hey ##{i} @#{user2.nickname}!"
          })
      end)

      {old, new} = Enum.split(Notification.for_user(user2), 5)

      Enum.each(old, fn notification ->
        notification
        |> cast(%{updated_at: days_ago(10)}, [:updated_at])
        |> Pleroma.Repo.update!()
      end)

      recent_notifications_ids =
        user2
        |> Notification.for_user_since(
          NaiveDateTime.add(NaiveDateTime.utc_now(), -5 * 86_400, :second)
        )
        |> Enum.map(& &1.id)

      Enum.each(old, fn %{id: id} ->
        refute id in recent_notifications_ids
      end)

      Enum.each(new, fn %{id: id} ->
        assert id in recent_notifications_ids
      end)
    end
  end

  describe "notification target determination" do
    test "it sends notifications to addressed users in new messages" do
      user = insert(:user)
      other_user = insert(:user)

      {:ok, activity} =
        CommonAPI.post(user, %{
          "status" => "hey @#{other_user.nickname}!"
        })

      assert other_user in Notification.get_notified_from_activity(activity)
    end

    test "it sends notifications to mentioned users in new messages" do
      user = insert(:user)
      other_user = insert(:user)

      create_activity = %{
        "@context" => "https://www.w3.org/ns/activitystreams",
        "type" => "Create",
        "to" => ["https://www.w3.org/ns/activitystreams#Public"],
        "actor" => user.ap_id,
        "object" => %{
          "type" => "Note",
          "content" => "message with a Mention tag, but no explicit tagging",
          "tag" => [
            %{
              "type" => "Mention",
              "href" => other_user.ap_id,
              "name" => other_user.nickname
            }
          ],
          "attributedTo" => user.ap_id
        }
      }

      {:ok, activity} = Transmogrifier.handle_incoming(create_activity)

      assert other_user in Notification.get_notified_from_activity(activity)
    end

    test "it does not send notifications to users who are only cc in new messages" do
      user = insert(:user)
      other_user = insert(:user)

      create_activity = %{
        "@context" => "https://www.w3.org/ns/activitystreams",
        "type" => "Create",
        "to" => ["https://www.w3.org/ns/activitystreams#Public"],
        "cc" => [other_user.ap_id],
        "actor" => user.ap_id,
        "object" => %{
          "type" => "Note",
          "content" => "hi everyone",
          "attributedTo" => user.ap_id
        }
      }

      {:ok, activity} = Transmogrifier.handle_incoming(create_activity)

      assert other_user not in Notification.get_notified_from_activity(activity)
    end

    test "it does not send notification to mentioned users in likes" do
      user = insert(:user)
      other_user = insert(:user)
      third_user = insert(:user)

      {:ok, activity_one} =
        CommonAPI.post(user, %{
          "status" => "hey @#{other_user.nickname}!"
        })

      {:ok, activity_two, _} = CommonAPI.favorite(activity_one.id, third_user)

      assert other_user not in Notification.get_notified_from_activity(activity_two)
    end

    test "it does not send notification to mentioned users in announces" do
      user = insert(:user)
      other_user = insert(:user)
      third_user = insert(:user)

      {:ok, activity_one} =
        CommonAPI.post(user, %{
          "status" => "hey @#{other_user.nickname}!"
        })

      {:ok, activity_two, _} = CommonAPI.repeat(activity_one.id, third_user)

      assert other_user not in Notification.get_notified_from_activity(activity_two)
    end
  end

  describe "notification lifecycle" do
    test "liking an activity results in 1 notification, then 0 if the activity is deleted" do
      user = insert(:user)
      other_user = insert(:user)

      {:ok, activity} = CommonAPI.post(user, %{"status" => "test post"})

      assert Enum.empty?(Notification.for_user(user))

      {:ok, _, _} = CommonAPI.favorite(activity.id, other_user)

      assert length(Notification.for_user(user)) == 1

      {:ok, _} = CommonAPI.delete(activity.id, user)

      assert Enum.empty?(Notification.for_user(user))
    end

    test "liking an activity results in 1 notification, then 0 if the activity is unliked" do
      user = insert(:user)
      other_user = insert(:user)

      {:ok, activity} = CommonAPI.post(user, %{"status" => "test post"})

      assert Enum.empty?(Notification.for_user(user))

      {:ok, _, _} = CommonAPI.favorite(activity.id, other_user)

      assert length(Notification.for_user(user)) == 1

      {:ok, _, _, _} = CommonAPI.unfavorite(activity.id, other_user)

      assert Enum.empty?(Notification.for_user(user))
    end

    test "repeating an activity results in 1 notification, then 0 if the activity is deleted" do
      user = insert(:user)
      other_user = insert(:user)

      {:ok, activity} = CommonAPI.post(user, %{"status" => "test post"})

      assert Enum.empty?(Notification.for_user(user))

      {:ok, _, _} = CommonAPI.repeat(activity.id, other_user)

      assert length(Notification.for_user(user)) == 1

      {:ok, _} = CommonAPI.delete(activity.id, user)

      assert Enum.empty?(Notification.for_user(user))
    end

    test "repeating an activity results in 1 notification, then 0 if the activity is unrepeated" do
      user = insert(:user)
      other_user = insert(:user)

      {:ok, activity} = CommonAPI.post(user, %{"status" => "test post"})

      assert Enum.empty?(Notification.for_user(user))

      {:ok, _, _} = CommonAPI.repeat(activity.id, other_user)

      assert length(Notification.for_user(user)) == 1

      {:ok, _, _} = CommonAPI.unrepeat(activity.id, other_user)

      assert Enum.empty?(Notification.for_user(user))
    end

    test "liking an activity which is already deleted does not generate a notification" do
      user = insert(:user)
      other_user = insert(:user)

      {:ok, activity} = CommonAPI.post(user, %{"status" => "test post"})

      assert Enum.empty?(Notification.for_user(user))

      {:ok, _deletion_activity} = CommonAPI.delete(activity.id, user)

      assert Enum.empty?(Notification.for_user(user))

      {:error, _} = CommonAPI.favorite(activity.id, other_user)

      assert Enum.empty?(Notification.for_user(user))
    end

    test "repeating an activity which is already deleted does not generate a notification" do
      user = insert(:user)
      other_user = insert(:user)

      {:ok, activity} = CommonAPI.post(user, %{"status" => "test post"})

      assert Enum.empty?(Notification.for_user(user))

      {:ok, _deletion_activity} = CommonAPI.delete(activity.id, user)

      assert Enum.empty?(Notification.for_user(user))

      {:error, _} = CommonAPI.repeat(activity.id, other_user)

      assert Enum.empty?(Notification.for_user(user))
    end

    test "replying to a deleted post without tagging does not generate a notification" do
      user = insert(:user)
      other_user = insert(:user)

      {:ok, activity} = CommonAPI.post(user, %{"status" => "test post"})
      {:ok, _deletion_activity} = CommonAPI.delete(activity.id, user)

      {:ok, _reply_activity} =
        CommonAPI.post(other_user, %{
          "status" => "test reply",
          "in_reply_to_status_id" => activity.id
        })

      assert Enum.empty?(Notification.for_user(user))
    end

    test "notifications are deleted if a local user is deleted" do
      user = insert(:user)
      other_user = insert(:user)

      {:ok, _activity} =
        CommonAPI.post(user, %{"status" => "hi @#{other_user.nickname}", "visibility" => "direct"})

      refute Enum.empty?(Notification.for_user(other_user))

      {:ok, job} = User.delete(user)
      ObanHelpers.perform(job)

      assert Enum.empty?(Notification.for_user(other_user))
    end

    test "notifications are deleted if a remote user is deleted" do
      remote_user = insert(:user)
      local_user = insert(:user)

      dm_message = %{
        "@context" => "https://www.w3.org/ns/activitystreams",
        "type" => "Create",
        "actor" => remote_user.ap_id,
        "id" => remote_user.ap_id <> "/activities/test",
        "to" => [local_user.ap_id],
        "cc" => [],
        "object" => %{
          "type" => "Note",
          "content" => "Hello!",
          "tag" => [
            %{
              "type" => "Mention",
              "href" => local_user.ap_id,
              "name" => "@#{local_user.nickname}"
            }
          ],
          "to" => [local_user.ap_id],
          "cc" => [],
          "attributedTo" => remote_user.ap_id
        }
      }

      {:ok, _dm_activity} = Transmogrifier.handle_incoming(dm_message)

      refute Enum.empty?(Notification.for_user(local_user))

      delete_user_message = %{
        "@context" => "https://www.w3.org/ns/activitystreams",
        "id" => remote_user.ap_id <> "/activities/delete",
        "actor" => remote_user.ap_id,
        "type" => "Delete",
        "object" => remote_user.ap_id
      }

      {:ok, _delete_activity} = Transmogrifier.handle_incoming(delete_user_message)
      ObanHelpers.perform_all()

      assert Enum.empty?(Notification.for_user(local_user))
    end

    test "move activity generates a notification" do
      %{ap_id: old_ap_id} = old_user = insert(:user)
      %{ap_id: new_ap_id} = new_user = insert(:user, also_known_as: [old_ap_id])
      follower = insert(:user)
      other_follower = insert(:user, %{allow_following_move: false})

      User.follow(follower, old_user)
      User.follow(other_follower, old_user)

      Pleroma.Web.ActivityPub.ActivityPub.move(old_user, new_user)
      ObanHelpers.perform_all()

      assert [] = Notification.for_user(follower)

      assert [
               %{
                 activity: %{
                   data: %{"type" => "Move", "actor" => ^old_ap_id, "target" => ^new_ap_id}
                 }
               }
             ] = Notification.for_user(follower, %{with_move: true})

      assert [] = Notification.for_user(other_follower)

      assert [
               %{
                 activity: %{
                   data: %{"type" => "Move", "actor" => ^old_ap_id, "target" => ^new_ap_id}
                 }
               }
             ] = Notification.for_user(other_follower, %{with_move: true})
    end
  end

  describe "for_user" do
    test "it returns notifications for muted user without notifications" do
      user = insert(:user)
      muted = insert(:user)
      {:ok, _user_relationships} = User.mute(user, muted, false)

      {:ok, _activity} = CommonAPI.post(muted, %{"status" => "hey @#{user.nickname}"})

      assert length(Notification.for_user(user)) == 1
    end

    test "it doesn't return notifications for muted user with notifications" do
      user = insert(:user)
      muted = insert(:user)
      {:ok, _user_relationships} = User.mute(user, muted)

      {:ok, _activity} = CommonAPI.post(muted, %{"status" => "hey @#{user.nickname}"})

      assert Notification.for_user(user) == []
    end

    test "it doesn't return notifications for blocked user" do
      user = insert(:user)
      blocked = insert(:user)
      {:ok, _user_relationship} = User.block(user, blocked)

      {:ok, _activity} = CommonAPI.post(blocked, %{"status" => "hey @#{user.nickname}"})

      assert Notification.for_user(user) == []
    end

    test "it doesn't return notificatitons for blocked domain" do
      user = insert(:user)
      blocked = insert(:user, ap_id: "http://some-domain.com")
      {:ok, user} = User.block_domain(user, "some-domain.com")

      {:ok, _activity} = CommonAPI.post(blocked, %{"status" => "hey @#{user.nickname}"})

      assert Notification.for_user(user) == []
    end

    test "it doesn't return notifications for muted thread" do
      user = insert(:user)
      another_user = insert(:user)

      {:ok, activity} = CommonAPI.post(another_user, %{"status" => "hey @#{user.nickname}"})

      {:ok, _} = Pleroma.ThreadMute.add_mute(user.id, activity.data["context"])
      assert Notification.for_user(user) == []
    end

    test "it returns notifications from a muted user when with_muted is set" do
      user = insert(:user)
      muted = insert(:user)
      {:ok, _user_relationships} = User.mute(user, muted)

      {:ok, _activity} = CommonAPI.post(muted, %{"status" => "hey @#{user.nickname}"})

      assert length(Notification.for_user(user, %{with_muted: true})) == 1
    end

    test "it doesn't return notifications from a blocked user when with_muted is set" do
      user = insert(:user)
      blocked = insert(:user)
      {:ok, _user_relationship} = User.block(user, blocked)

      {:ok, _activity} = CommonAPI.post(blocked, %{"status" => "hey @#{user.nickname}"})

      assert Enum.empty?(Notification.for_user(user, %{with_muted: true}))
    end

    test "it doesn't return notifications from a domain-blocked user when with_muted is set" do
      user = insert(:user)
      blocked = insert(:user, ap_id: "http://some-domain.com")
      {:ok, user} = User.block_domain(user, "some-domain.com")

      {:ok, _activity} = CommonAPI.post(blocked, %{"status" => "hey @#{user.nickname}"})

      assert Enum.empty?(Notification.for_user(user, %{with_muted: true}))
    end

    test "it returns notifications from muted threads when with_muted is set" do
      user = insert(:user)
      another_user = insert(:user)

      {:ok, activity} = CommonAPI.post(another_user, %{"status" => "hey @#{user.nickname}"})

      {:ok, _} = Pleroma.ThreadMute.add_mute(user.id, activity.data["context"])
      assert length(Notification.for_user(user, %{with_muted: true})) == 1
    end
  end
end
