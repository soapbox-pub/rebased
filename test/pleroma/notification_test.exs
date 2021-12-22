# Pleroma: A lightweight social networking server
# Copyright © 2017-2021 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.NotificationTest do
  use Pleroma.DataCase

  import Pleroma.Factory
  import Mock

  alias Pleroma.FollowingRelationship
  alias Pleroma.Notification
  alias Pleroma.Repo
  alias Pleroma.Tests.ObanHelpers
  alias Pleroma.User
  alias Pleroma.Web.ActivityPub.ActivityPub
  alias Pleroma.Web.ActivityPub.Builder
  alias Pleroma.Web.ActivityPub.Transmogrifier
  alias Pleroma.Web.CommonAPI
  alias Pleroma.Web.MastodonAPI.NotificationView
  alias Pleroma.Web.Push
  alias Pleroma.Web.Streamer

  describe "create_notifications" do
    test "never returns nil" do
      user = insert(:user)
      other_user = insert(:user, %{invisible: true})

      {:ok, activity} = CommonAPI.post(user, %{status: "yeah"})
      {:ok, activity} = CommonAPI.react_with_emoji(activity.id, other_user, "☕")

      refute {:ok, [nil]} == Notification.create_notifications(activity)
    end

    test "creates a notification for a report" do
      reporting_user = insert(:user)
      reported_user = insert(:user)
      {:ok, moderator_user} = insert(:user) |> User.admin_api_update(%{is_moderator: true})

      {:ok, activity} = CommonAPI.report(reporting_user, %{account_id: reported_user.id})

      {:ok, [notification]} = Notification.create_notifications(activity)

      assert notification.user_id == moderator_user.id
      assert notification.type == "pleroma:report"
    end

    test "suppresses notification to reporter if reporter is an admin" do
      reporting_admin = insert(:user, is_admin: true)
      reported_user = insert(:user)
      other_admin = insert(:user, is_admin: true)

      {:ok, activity} = CommonAPI.report(reporting_admin, %{account_id: reported_user.id})

      {:ok, [notification]} = Notification.create_notifications(activity)

      refute notification.user_id == reporting_admin.id
      assert notification.user_id == other_admin.id
      assert notification.type == "pleroma:report"
    end

    test "creates a notification for an emoji reaction" do
      user = insert(:user)
      other_user = insert(:user)

      {:ok, activity} = CommonAPI.post(user, %{status: "yeah"})
      {:ok, activity} = CommonAPI.react_with_emoji(activity.id, other_user, "☕")

      {:ok, [notification]} = Notification.create_notifications(activity)

      assert notification.user_id == user.id
      assert notification.type == "pleroma:emoji_reaction"
    end

    test "notifies someone when they are directly addressed" do
      user = insert(:user)
      other_user = insert(:user)
      third_user = insert(:user)

      {:ok, activity} =
        CommonAPI.post(user, %{
          status: "hey @#{other_user.nickname} and @#{third_user.nickname}"
        })

      {:ok, [notification, other_notification]} = Notification.create_notifications(activity)

      notified_ids = Enum.sort([notification.user_id, other_notification.user_id])
      assert notified_ids == [other_user.id, third_user.id]
      assert notification.activity_id == activity.id
      assert notification.type == "mention"
      assert other_notification.activity_id == activity.id

      assert [%Pleroma.Marker{unread_count: 2}] =
               Pleroma.Marker.get_markers(other_user, ["notifications"])
    end

    test "it creates a notification for subscribed users" do
      user = insert(:user)
      subscriber = insert(:user)

      User.subscribe(subscriber, user)

      {:ok, status} = CommonAPI.post(user, %{status: "Akariiiin"})
      {:ok, [notification]} = Notification.create_notifications(status)

      assert notification.user_id == subscriber.id
    end

    test "does not create a notification for subscribed users if status is a reply" do
      user = insert(:user)
      other_user = insert(:user)
      subscriber = insert(:user)

      User.subscribe(subscriber, other_user)

      {:ok, activity} = CommonAPI.post(user, %{status: "test post"})

      {:ok, _reply_activity} =
        CommonAPI.post(other_user, %{
          status: "test reply",
          in_reply_to_status_id: activity.id
        })

      user_notifications = Notification.for_user(user)
      assert length(user_notifications) == 1

      subscriber_notifications = Notification.for_user(subscriber)
      assert Enum.empty?(subscriber_notifications)
    end
  end

  test "create_poll_notifications/1" do
    [user1, user2, user3, _, _] = insert_list(5, :user)
    question = insert(:question, user: user1)
    activity = insert(:question_activity, question: question)

    {:ok, _, _} = CommonAPI.vote(user2, question, [0])
    {:ok, _, _} = CommonAPI.vote(user3, question, [1])

    {:ok, notifications} = Notification.create_poll_notifications(activity)

    assert [user2.id, user3.id, user1.id] == Enum.map(notifications, & &1.user_id)
  end

  describe "CommonApi.post/2 notification-related functionality" do
    test_with_mock "creates but does NOT send notification to blocker user",
                   Push,
                   [:passthrough],
                   [] do
      user = insert(:user)
      blocker = insert(:user)
      {:ok, _user_relationship} = User.block(blocker, user)

      {:ok, _activity} = CommonAPI.post(user, %{status: "hey @#{blocker.nickname}!"})

      blocker_id = blocker.id
      assert [%Notification{user_id: ^blocker_id}] = Repo.all(Notification)
      refute called(Push.send(:_))
    end

    test_with_mock "creates but does NOT send notification to notification-muter user",
                   Push,
                   [:passthrough],
                   [] do
      user = insert(:user)
      muter = insert(:user)
      {:ok, _user_relationships} = User.mute(muter, user)

      {:ok, _activity} = CommonAPI.post(user, %{status: "hey @#{muter.nickname}!"})

      muter_id = muter.id
      assert [%Notification{user_id: ^muter_id}] = Repo.all(Notification)
      refute called(Push.send(:_))
    end

    test_with_mock "creates but does NOT send notification to thread-muter user",
                   Push,
                   [:passthrough],
                   [] do
      user = insert(:user)
      thread_muter = insert(:user)

      {:ok, activity} = CommonAPI.post(user, %{status: "hey @#{thread_muter.nickname}!"})

      {:ok, _} = CommonAPI.add_mute(thread_muter, activity)

      {:ok, _same_context_activity} =
        CommonAPI.post(user, %{
          status: "hey-hey-hey @#{thread_muter.nickname}!",
          in_reply_to_status_id: activity.id
        })

      [pre_mute_notification, post_mute_notification] =
        Repo.all(from(n in Notification, where: n.user_id == ^thread_muter.id, order_by: n.id))

      pre_mute_notification_id = pre_mute_notification.id
      post_mute_notification_id = post_mute_notification.id

      assert called(
               Push.send(
                 :meck.is(fn
                   %Notification{id: ^pre_mute_notification_id} -> true
                   _ -> false
                 end)
               )
             )

      refute called(
               Push.send(
                 :meck.is(fn
                   %Notification{id: ^post_mute_notification_id} -> true
                   _ -> false
                 end)
               )
             )
    end
  end

  describe "create_notification" do
    @tag needs_streamer: true
    test "it creates a notification for user and send to the 'user' and the 'user:notification' stream" do
      %{user: user, token: oauth_token} = oauth_access(["read"])

      task =
        Task.async(fn ->
          {:ok, _topic} = Streamer.get_topic_and_add_socket("user", user, oauth_token)
          assert_receive {:render_with_user, _, _, _}, 4_000
        end)

      task_user_notification =
        Task.async(fn ->
          {:ok, _topic} =
            Streamer.get_topic_and_add_socket("user:notification", user, oauth_token)

          assert_receive {:render_with_user, _, _, _}, 4_000
        end)

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
      {:ok, activity} = CommonAPI.post(muted, %{status: "Hi @#{muter.nickname}"})

      notification = Notification.create_notification(activity, muter)

      assert notification.id
      assert notification.seen
    end

    test "notification created if user is muted without notifications" do
      muter = insert(:user)
      muted = insert(:user)

      {:ok, _user_relationships} = User.mute(muter, muted, %{notifications: false})

      {:ok, activity} = CommonAPI.post(muted, %{status: "Hi @#{muter.nickname}"})

      assert Notification.create_notification(activity, muter)
    end

    test "it creates a notification for an activity from a muted thread" do
      muter = insert(:user)
      other_user = insert(:user)
      {:ok, activity} = CommonAPI.post(muter, %{status: "hey"})
      CommonAPI.add_mute(muter, activity)

      {:ok, activity} =
        CommonAPI.post(other_user, %{
          status: "Hi @#{muter.nickname}",
          in_reply_to_status_id: activity.id
        })

      notification = Notification.create_notification(activity, muter)

      assert notification.id
      assert notification.seen
    end

    test "it disables notifications from strangers" do
      follower = insert(:user)

      followed =
        insert(:user,
          notification_settings: %Pleroma.User.NotificationSetting{block_from_strangers: true}
        )

      {:ok, activity} = CommonAPI.post(follower, %{status: "hey @#{followed.nickname}"})
      refute Notification.create_notification(activity, followed)
    end

    test "it doesn't create a notification for user if he is the activity author" do
      activity = insert(:note_activity)
      author = User.get_cached_by_ap_id(activity.data["actor"])

      refute Notification.create_notification(activity, author)
    end

    test "it doesn't create duplicate notifications for follow+subscribed users" do
      user = insert(:user)
      subscriber = insert(:user)

      {:ok, _, _, _} = CommonAPI.follow(subscriber, user)
      User.subscribe(subscriber, user)
      {:ok, status} = CommonAPI.post(user, %{status: "Akariiiin"})
      {:ok, [_notif]} = Notification.create_notifications(status)
    end

    test "it doesn't create subscription notifications if the recipient cannot see the status" do
      user = insert(:user)
      subscriber = insert(:user)

      User.subscribe(subscriber, user)

      {:ok, status} = CommonAPI.post(user, %{status: "inwisible", visibility: "direct"})

      assert {:ok, []} == Notification.create_notifications(status)
    end

    test "it disables notifications from people who are invisible" do
      author = insert(:user, invisible: true)
      user = insert(:user)

      {:ok, status} = CommonAPI.post(author, %{status: "hey @#{user.nickname}"})
      refute Notification.create_notification(status, user)
    end

    test "it doesn't create notifications if content matches with an irreversible filter" do
      user = insert(:user)
      subscriber = insert(:user)

      User.subscribe(subscriber, user)
      insert(:filter, user: subscriber, phrase: "cofe", hide: true)

      {:ok, status} = CommonAPI.post(user, %{status: "got cofe?"})

      assert {:ok, []} == Notification.create_notifications(status)
    end

    test "it creates notifications if content matches with a not irreversible filter" do
      user = insert(:user)
      subscriber = insert(:user)

      User.subscribe(subscriber, user)
      insert(:filter, user: subscriber, phrase: "cofe", hide: false)

      {:ok, status} = CommonAPI.post(user, %{status: "got cofe?"})
      {:ok, [notification]} = Notification.create_notifications(status)

      assert notification
      refute notification.seen
    end

    test "it creates notifications when someone likes user's status with a filtered word" do
      user = insert(:user)
      other_user = insert(:user)
      insert(:filter, user: user, phrase: "tesla", hide: true)

      {:ok, activity_one} = CommonAPI.post(user, %{status: "wow tesla"})
      {:ok, activity_two} = CommonAPI.favorite(other_user, activity_one.id)

      {:ok, [notification]} = Notification.create_notifications(activity_two)

      assert notification
      refute notification.seen
    end
  end

  describe "follow / follow_request notifications" do
    test "it creates `follow` notification for approved Follow activity" do
      user = insert(:user)
      followed_user = insert(:user, is_locked: false)

      {:ok, _, _, _activity} = CommonAPI.follow(user, followed_user)
      assert FollowingRelationship.following?(user, followed_user)
      assert [notification] = Notification.for_user(followed_user)

      assert %{type: "follow"} =
               NotificationView.render("show.json", %{
                 notification: notification,
                 for: followed_user
               })
    end

    test "it creates `follow_request` notification for pending Follow activity" do
      user = insert(:user)
      followed_user = insert(:user, is_locked: true)

      {:ok, _, _, _activity} = CommonAPI.follow(user, followed_user)
      refute FollowingRelationship.following?(user, followed_user)
      assert [notification] = Notification.for_user(followed_user)

      render_opts = %{notification: notification, for: followed_user}
      assert %{type: "follow_request"} = NotificationView.render("show.json", render_opts)

      # After request is accepted, the same notification is rendered with type "follow":
      assert {:ok, _} = CommonAPI.accept_follow_request(user, followed_user)

      notification =
        Repo.get(Notification, notification.id)
        |> Repo.preload(:activity)

      assert %{type: "follow"} =
               NotificationView.render("show.json", notification: notification, for: followed_user)
    end

    test "it doesn't create a notification for follow-unfollow-follow chains" do
      user = insert(:user)
      followed_user = insert(:user, is_locked: false)

      {:ok, _, _, _activity} = CommonAPI.follow(user, followed_user)
      assert FollowingRelationship.following?(user, followed_user)
      assert [notification] = Notification.for_user(followed_user)

      CommonAPI.unfollow(user, followed_user)
      {:ok, _, _, _activity_dupe} = CommonAPI.follow(user, followed_user)

      notification_id = notification.id
      assert [%{id: ^notification_id}] = Notification.for_user(followed_user)
    end

    test "dismisses the notification on follow request rejection" do
      user = insert(:user, is_locked: true)
      follower = insert(:user)
      {:ok, _, _, _follow_activity} = CommonAPI.follow(follower, user)
      assert [_notification] = Notification.for_user(user)
      {:ok, _follower} = CommonAPI.reject_follow_request(follower, user)
      assert [] = Notification.for_user(user)
    end
  end

  describe "get notification" do
    test "it gets a notification that belongs to the user" do
      user = insert(:user)
      other_user = insert(:user)

      {:ok, activity} = CommonAPI.post(user, %{status: "hey @#{other_user.nickname}"})

      {:ok, [notification]} = Notification.create_notifications(activity)
      {:ok, notification} = Notification.get(other_user, notification.id)

      assert notification.user_id == other_user.id
    end

    test "it returns error if the notification doesn't belong to the user" do
      user = insert(:user)
      other_user = insert(:user)

      {:ok, activity} = CommonAPI.post(user, %{status: "hey @#{other_user.nickname}"})

      {:ok, [notification]} = Notification.create_notifications(activity)
      {:error, _notification} = Notification.get(user, notification.id)
    end
  end

  describe "dismiss notification" do
    test "it dismisses a notification that belongs to the user" do
      user = insert(:user)
      other_user = insert(:user)

      {:ok, activity} = CommonAPI.post(user, %{status: "hey @#{other_user.nickname}"})

      {:ok, [notification]} = Notification.create_notifications(activity)
      {:ok, notification} = Notification.dismiss(other_user, notification.id)

      assert notification.user_id == other_user.id
    end

    test "it returns error if the notification doesn't belong to the user" do
      user = insert(:user)
      other_user = insert(:user)

      {:ok, activity} = CommonAPI.post(user, %{status: "hey @#{other_user.nickname}"})

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
          status: "hey @#{other_user.nickname} and @#{third_user.nickname} !"
        })

      {:ok, _notifs} = Notification.create_notifications(activity)

      {:ok, activity} =
        CommonAPI.post(user, %{
          status: "hey again @#{other_user.nickname} and @#{third_user.nickname} !"
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
          status: "hey @#{other_user.nickname}!"
        })

      {:ok, _activity} =
        CommonAPI.post(user, %{
          status: "hey again @#{other_user.nickname}!"
        })

      [n2, n1] = Notification.for_user(other_user)

      assert n2.id > n1.id

      {:ok, _activity} =
        CommonAPI.post(user, %{
          status: "hey yet again @#{other_user.nickname}!"
        })

      [_, read_notification] = Notification.set_read_up_to(other_user, n2.id)

      assert read_notification.activity.object

      [n3, n2, n1] = Notification.for_user(other_user)

      assert n1.seen == true
      assert n2.seen == true
      assert n3.seen == false

      assert %Pleroma.Marker{} =
               m =
               Pleroma.Repo.get_by(
                 Pleroma.Marker,
                 user_id: other_user.id,
                 timeline: "notifications"
               )

      assert m.last_read_id == to_string(n2.id)
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
            status: "hey ##{i} @#{user2.nickname}!"
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

  describe "notification target determination / get_notified_from_activity/2" do
    test "it sends notifications to addressed users in new messages" do
      user = insert(:user)
      other_user = insert(:user)

      {:ok, activity} =
        CommonAPI.post(user, %{
          status: "hey @#{other_user.nickname}!"
        })

      {enabled_receivers, _disabled_receivers} = Notification.get_notified_from_activity(activity)

      assert other_user in enabled_receivers
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
          "id" => Pleroma.Web.ActivityPub.Utils.generate_object_id(),
          "to" => ["https://www.w3.org/ns/activitystreams#Public"],
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

      {enabled_receivers, _disabled_receivers} = Notification.get_notified_from_activity(activity)

      assert other_user in enabled_receivers
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
          "id" => Pleroma.Web.ActivityPub.Utils.generate_object_id(),
          "to" => ["https://www.w3.org/ns/activitystreams#Public"],
          "cc" => [other_user.ap_id],
          "content" => "hi everyone",
          "attributedTo" => user.ap_id
        }
      }

      {:ok, activity} = Transmogrifier.handle_incoming(create_activity)

      {enabled_receivers, _disabled_receivers} = Notification.get_notified_from_activity(activity)

      assert other_user not in enabled_receivers
    end

    test "it does not send notification to mentioned users in likes" do
      user = insert(:user)
      other_user = insert(:user)
      third_user = insert(:user)

      {:ok, activity_one} =
        CommonAPI.post(user, %{
          status: "hey @#{other_user.nickname}!"
        })

      {:ok, activity_two} = CommonAPI.favorite(third_user, activity_one.id)

      {enabled_receivers, _disabled_receivers} =
        Notification.get_notified_from_activity(activity_two)

      assert other_user not in enabled_receivers
    end

    test "it only notifies the post's author in likes" do
      user = insert(:user)
      other_user = insert(:user)
      third_user = insert(:user)

      {:ok, activity_one} =
        CommonAPI.post(user, %{
          status: "hey @#{other_user.nickname}!"
        })

      {:ok, like_data, _} = Builder.like(third_user, activity_one.object)

      {:ok, like, _} =
        like_data
        |> Map.put("to", [other_user.ap_id | like_data["to"]])
        |> ActivityPub.persist(local: true)

      {enabled_receivers, _disabled_receivers} = Notification.get_notified_from_activity(like)

      assert other_user not in enabled_receivers
    end

    test "it does not send notification to mentioned users in announces" do
      user = insert(:user)
      other_user = insert(:user)
      third_user = insert(:user)

      {:ok, activity_one} =
        CommonAPI.post(user, %{
          status: "hey @#{other_user.nickname}!"
        })

      {:ok, activity_two} = CommonAPI.repeat(activity_one.id, third_user)

      {enabled_receivers, _disabled_receivers} =
        Notification.get_notified_from_activity(activity_two)

      assert other_user not in enabled_receivers
    end

    test "it returns blocking recipient in disabled recipients list" do
      user = insert(:user)
      other_user = insert(:user)
      {:ok, _user_relationship} = User.block(other_user, user)

      {:ok, activity} = CommonAPI.post(user, %{status: "hey @#{other_user.nickname}!"})

      {enabled_receivers, disabled_receivers} = Notification.get_notified_from_activity(activity)

      assert [] == enabled_receivers
      assert [other_user] == disabled_receivers
    end

    test "it returns notification-muting recipient in disabled recipients list" do
      user = insert(:user)
      other_user = insert(:user)
      {:ok, _user_relationships} = User.mute(other_user, user)

      {:ok, activity} = CommonAPI.post(user, %{status: "hey @#{other_user.nickname}!"})

      {enabled_receivers, disabled_receivers} = Notification.get_notified_from_activity(activity)

      assert [] == enabled_receivers
      assert [other_user] == disabled_receivers
    end

    test "it returns thread-muting recipient in disabled recipients list" do
      user = insert(:user)
      other_user = insert(:user)

      {:ok, activity} = CommonAPI.post(user, %{status: "hey @#{other_user.nickname}!"})

      {:ok, _} = CommonAPI.add_mute(other_user, activity)

      {:ok, same_context_activity} =
        CommonAPI.post(user, %{
          status: "hey-hey-hey @#{other_user.nickname}!",
          in_reply_to_status_id: activity.id
        })

      {enabled_receivers, disabled_receivers} =
        Notification.get_notified_from_activity(same_context_activity)

      assert [other_user] == disabled_receivers
      refute other_user in enabled_receivers
    end

    test "it returns non-following domain-blocking recipient in disabled recipients list" do
      blocked_domain = "blocked.domain"
      user = insert(:user, %{ap_id: "https://#{blocked_domain}/@actor"})
      other_user = insert(:user)

      {:ok, other_user} = User.block_domain(other_user, blocked_domain)

      {:ok, activity} = CommonAPI.post(user, %{status: "hey @#{other_user.nickname}!"})

      {enabled_receivers, disabled_receivers} = Notification.get_notified_from_activity(activity)

      assert [] == enabled_receivers
      assert [other_user] == disabled_receivers
    end

    test "it returns following domain-blocking recipient in enabled recipients list" do
      blocked_domain = "blocked.domain"
      user = insert(:user, %{ap_id: "https://#{blocked_domain}/@actor"})
      other_user = insert(:user)

      {:ok, other_user} = User.block_domain(other_user, blocked_domain)
      {:ok, other_user, user} = User.follow(other_user, user)

      {:ok, activity} = CommonAPI.post(user, %{status: "hey @#{other_user.nickname}!"})

      {enabled_receivers, disabled_receivers} = Notification.get_notified_from_activity(activity)

      assert [other_user] == enabled_receivers
      assert [] == disabled_receivers
    end
  end

  describe "notification lifecycle" do
    test "liking an activity results in 1 notification, then 0 if the activity is deleted" do
      user = insert(:user)
      other_user = insert(:user)

      {:ok, activity} = CommonAPI.post(user, %{status: "test post"})

      assert Enum.empty?(Notification.for_user(user))

      {:ok, _} = CommonAPI.favorite(other_user, activity.id)

      assert length(Notification.for_user(user)) == 1

      {:ok, _} = CommonAPI.delete(activity.id, user)

      assert Enum.empty?(Notification.for_user(user))
    end

    test "liking an activity results in 1 notification, then 0 if the activity is unliked" do
      user = insert(:user)
      other_user = insert(:user)

      {:ok, activity} = CommonAPI.post(user, %{status: "test post"})

      assert Enum.empty?(Notification.for_user(user))

      {:ok, _} = CommonAPI.favorite(other_user, activity.id)

      assert length(Notification.for_user(user)) == 1

      {:ok, _} = CommonAPI.unfavorite(activity.id, other_user)

      assert Enum.empty?(Notification.for_user(user))
    end

    test "repeating an activity results in 1 notification, then 0 if the activity is deleted" do
      user = insert(:user)
      other_user = insert(:user)

      {:ok, activity} = CommonAPI.post(user, %{status: "test post"})

      assert Enum.empty?(Notification.for_user(user))

      {:ok, _} = CommonAPI.repeat(activity.id, other_user)

      assert length(Notification.for_user(user)) == 1

      {:ok, _} = CommonAPI.delete(activity.id, user)

      assert Enum.empty?(Notification.for_user(user))
    end

    test "repeating an activity results in 1 notification, then 0 if the activity is unrepeated" do
      user = insert(:user)
      other_user = insert(:user)

      {:ok, activity} = CommonAPI.post(user, %{status: "test post"})

      assert Enum.empty?(Notification.for_user(user))

      {:ok, _} = CommonAPI.repeat(activity.id, other_user)

      assert length(Notification.for_user(user)) == 1

      {:ok, _} = CommonAPI.unrepeat(activity.id, other_user)

      assert Enum.empty?(Notification.for_user(user))
    end

    test "liking an activity which is already deleted does not generate a notification" do
      user = insert(:user)
      other_user = insert(:user)

      {:ok, activity} = CommonAPI.post(user, %{status: "test post"})

      assert Enum.empty?(Notification.for_user(user))

      {:ok, _deletion_activity} = CommonAPI.delete(activity.id, user)

      assert Enum.empty?(Notification.for_user(user))

      {:error, :not_found} = CommonAPI.favorite(other_user, activity.id)

      assert Enum.empty?(Notification.for_user(user))
    end

    test "repeating an activity which is already deleted does not generate a notification" do
      user = insert(:user)
      other_user = insert(:user)

      {:ok, activity} = CommonAPI.post(user, %{status: "test post"})

      assert Enum.empty?(Notification.for_user(user))

      {:ok, _deletion_activity} = CommonAPI.delete(activity.id, user)

      assert Enum.empty?(Notification.for_user(user))

      {:error, _} = CommonAPI.repeat(activity.id, other_user)

      assert Enum.empty?(Notification.for_user(user))
    end

    test "replying to a deleted post without tagging does not generate a notification" do
      user = insert(:user)
      other_user = insert(:user)

      {:ok, activity} = CommonAPI.post(user, %{status: "test post"})
      {:ok, _deletion_activity} = CommonAPI.delete(activity.id, user)

      {:ok, _reply_activity} =
        CommonAPI.post(other_user, %{
          status: "test reply",
          in_reply_to_status_id: activity.id
        })

      assert Enum.empty?(Notification.for_user(user))
    end

    test "notifications are deleted if a local user is deleted" do
      user = insert(:user)
      other_user = insert(:user)

      {:ok, _activity} =
        CommonAPI.post(user, %{status: "hi @#{other_user.nickname}", visibility: "direct"})

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
          "id" => remote_user.ap_id <> "/objects/test",
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

      remote_user_url = remote_user.ap_id

      Tesla.Mock.mock(fn
        %{method: :get, url: ^remote_user_url} ->
          %Tesla.Env{status: 404, body: ""}
      end)

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

      assert [
               %{
                 activity: %{
                   data: %{"type" => "Move", "actor" => ^old_ap_id, "target" => ^new_ap_id}
                 }
               }
             ] = Notification.for_user(follower)

      assert [
               %{
                 activity: %{
                   data: %{"type" => "Move", "actor" => ^old_ap_id, "target" => ^new_ap_id}
                 }
               }
             ] = Notification.for_user(other_follower)
    end
  end

  describe "for_user" do
    setup do
      user = insert(:user)

      {:ok, %{user: user}}
    end

    test "it returns notifications for muted user without notifications", %{user: user} do
      muted = insert(:user)
      {:ok, _user_relationships} = User.mute(user, muted, %{notifications: false})

      {:ok, _activity} = CommonAPI.post(muted, %{status: "hey @#{user.nickname}"})

      [notification] = Notification.for_user(user)

      assert notification.activity.object
      assert notification.seen
    end

    test "it doesn't return notifications for muted user with notifications", %{user: user} do
      muted = insert(:user)
      {:ok, _user_relationships} = User.mute(user, muted)

      {:ok, _activity} = CommonAPI.post(muted, %{status: "hey @#{user.nickname}"})

      assert Notification.for_user(user) == []
    end

    test "it doesn't return notifications for blocked user", %{user: user} do
      blocked = insert(:user)
      {:ok, _user_relationship} = User.block(user, blocked)

      {:ok, _activity} = CommonAPI.post(blocked, %{status: "hey @#{user.nickname}"})

      assert Notification.for_user(user) == []
    end

    test "it doesn't return notifications for domain-blocked non-followed user", %{user: user} do
      blocked = insert(:user, ap_id: "http://some-domain.com")
      {:ok, user} = User.block_domain(user, "some-domain.com")

      {:ok, _activity} = CommonAPI.post(blocked, %{status: "hey @#{user.nickname}"})

      assert Notification.for_user(user) == []
    end

    test "it returns notifications for domain-blocked but followed user" do
      user = insert(:user)
      blocked = insert(:user, ap_id: "http://some-domain.com")

      {:ok, user} = User.block_domain(user, "some-domain.com")
      {:ok, _, _} = User.follow(user, blocked)

      {:ok, _activity} = CommonAPI.post(blocked, %{status: "hey @#{user.nickname}"})

      assert length(Notification.for_user(user)) == 1
    end

    test "it doesn't return notifications for muted thread", %{user: user} do
      another_user = insert(:user)

      {:ok, activity} = CommonAPI.post(another_user, %{status: "hey @#{user.nickname}"})

      {:ok, _} = Pleroma.ThreadMute.add_mute(user.id, activity.data["context"])
      assert Notification.for_user(user) == []
    end

    test "it returns notifications from a muted user when with_muted is set", %{user: user} do
      muted = insert(:user)
      {:ok, _user_relationships} = User.mute(user, muted)

      {:ok, _activity} = CommonAPI.post(muted, %{status: "hey @#{user.nickname}"})

      assert length(Notification.for_user(user, %{with_muted: true})) == 1
    end

    test "it doesn't return notifications from a blocked user when with_muted is set", %{
      user: user
    } do
      blocked = insert(:user)
      {:ok, _user_relationship} = User.block(user, blocked)

      {:ok, _activity} = CommonAPI.post(blocked, %{status: "hey @#{user.nickname}"})

      assert Enum.empty?(Notification.for_user(user, %{with_muted: true}))
    end

    test "when with_muted is set, " <>
           "it doesn't return notifications from a domain-blocked non-followed user",
         %{user: user} do
      blocked = insert(:user, ap_id: "http://some-domain.com")
      {:ok, user} = User.block_domain(user, "some-domain.com")

      {:ok, _activity} = CommonAPI.post(blocked, %{status: "hey @#{user.nickname}"})

      assert Enum.empty?(Notification.for_user(user, %{with_muted: true}))
    end

    test "it returns notifications from muted threads when with_muted is set", %{user: user} do
      another_user = insert(:user)

      {:ok, activity} = CommonAPI.post(another_user, %{status: "hey @#{user.nickname}"})

      {:ok, _} = Pleroma.ThreadMute.add_mute(user.id, activity.data["context"])
      assert length(Notification.for_user(user, %{with_muted: true})) == 1
    end

    test "it doesn't return notifications about mentions with filtered word", %{user: user} do
      insert(:filter, user: user, phrase: "cofe", hide: true)
      another_user = insert(:user)

      {:ok, _activity} = CommonAPI.post(another_user, %{status: "@#{user.nickname} got cofe?"})

      assert Enum.empty?(Notification.for_user(user))
    end

    test "it returns notifications about mentions with not hidden filtered word", %{user: user} do
      insert(:filter, user: user, phrase: "test", hide: false)
      another_user = insert(:user)

      {:ok, _} = CommonAPI.post(another_user, %{status: "@#{user.nickname} test"})

      assert length(Notification.for_user(user)) == 1
    end

    test "it returns notifications about favorites with filtered word", %{user: user} do
      insert(:filter, user: user, phrase: "cofe", hide: true)
      another_user = insert(:user)

      {:ok, activity} = CommonAPI.post(user, %{status: "Give me my cofe!"})
      {:ok, _} = CommonAPI.favorite(another_user, activity.id)

      assert length(Notification.for_user(user)) == 1
    end
  end
end
