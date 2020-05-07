# Pleroma: A lightweight social networking server
# Copyright © 2017-2020 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.StreamerTest do
  use Pleroma.DataCase

  import Pleroma.Factory

  alias Pleroma.Conversation.Participation
  alias Pleroma.List
  alias Pleroma.User
  alias Pleroma.Web.CommonAPI
  alias Pleroma.Web.Streamer

  @moduletag needs_streamer: true, capture_log: true

  setup do: clear_config([:instance, :skip_thread_containment])

  describe "user streams" do
    setup do
      user = insert(:user)
      notify = insert(:notification, user: user, activity: build(:note_activity))
      {:ok, %{user: user, notify: notify}}
    end

    test "it streams the user's post in the 'user' stream", %{user: user} do
      Streamer.add_socket("user", user)
      {:ok, activity} = CommonAPI.post(user, %{"status" => "hey"})
      assert_receive {:render_with_user, _, _, ^activity}
      refute Streamer.filtered_by_user?(user, activity)
    end

    test "it streams boosts of the user in the 'user' stream", %{user: user} do
      Streamer.add_socket("user", user)

      other_user = insert(:user)
      {:ok, activity} = CommonAPI.post(other_user, %{"status" => "hey"})
      {:ok, announce, _} = CommonAPI.repeat(activity.id, user)

      assert_receive {:render_with_user, Pleroma.Web.StreamerView, "update.json", ^announce}
      refute Streamer.filtered_by_user?(user, announce)
    end

    test "it sends notify to in the 'user' stream", %{user: user, notify: notify} do
      Streamer.add_socket("user", user)
      Streamer.stream("user", notify)
      assert_receive {:render_with_user, _, _, ^notify}
      refute Streamer.filtered_by_user?(user, notify)
    end

    test "it sends notify to in the 'user:notification' stream", %{user: user, notify: notify} do
      Streamer.add_socket("user:notification", user)
      Streamer.stream("user:notification", notify)
      assert_receive {:render_with_user, _, _, ^notify}
      refute Streamer.filtered_by_user?(user, notify)
    end

    test "it doesn't send notify to the 'user:notification' stream when a user is blocked", %{
      user: user
    } do
      blocked = insert(:user)
      {:ok, _user_relationship} = User.block(user, blocked)

      Streamer.add_socket("user:notification", user)

      {:ok, activity} = CommonAPI.post(user, %{"status" => ":("})
      {:ok, _} = CommonAPI.favorite(blocked, activity.id)

      refute_receive _
    end

    test "it doesn't send notify to the 'user:notification' stream when a thread is muted", %{
      user: user
    } do
      user2 = insert(:user)

      {:ok, activity} = CommonAPI.post(user, %{"status" => "super hot take"})
      {:ok, _} = CommonAPI.add_mute(user, activity)

      Streamer.add_socket("user:notification", user)

      {:ok, favorite_activity} = CommonAPI.favorite(user2, activity.id)

      refute_receive _
      assert Streamer.filtered_by_user?(user, favorite_activity)
    end

    test "it sends favorite to 'user:notification' stream'", %{
      user: user
    } do
      user2 = insert(:user, %{ap_id: "https://hecking-lewd-place.com/user/meanie"})

      {:ok, activity} = CommonAPI.post(user, %{"status" => "super hot take"})
      Streamer.add_socket("user:notification", user)
      {:ok, favorite_activity} = CommonAPI.favorite(user2, activity.id)

      assert_receive {:render_with_user, _, "notification.json", notif}
      assert notif.activity.id == favorite_activity.id
      refute Streamer.filtered_by_user?(user, notif)
    end

    test "it doesn't send the 'user:notification' stream' when a domain is blocked", %{
      user: user
    } do
      user2 = insert(:user, %{ap_id: "https://hecking-lewd-place.com/user/meanie"})

      {:ok, user} = User.block_domain(user, "hecking-lewd-place.com")
      {:ok, activity} = CommonAPI.post(user, %{"status" => "super hot take"})
      Streamer.add_socket("user:notification", user)
      {:ok, favorite_activity} = CommonAPI.favorite(user2, activity.id)

      refute_receive _
      assert Streamer.filtered_by_user?(user, favorite_activity)
    end

    test "it sends follow activities to the 'user:notification' stream", %{
      user: user
    } do
      user_url = user.ap_id
      user2 = insert(:user)

      body =
        File.read!("test/fixtures/users_mock/localhost.json")
        |> String.replace("{{nickname}}", user.nickname)
        |> Jason.encode!()

      Tesla.Mock.mock_global(fn
        %{method: :get, url: ^user_url} ->
          %Tesla.Env{status: 200, body: body}
      end)

      Streamer.add_socket("user:notification", user)
      {:ok, _follower, _followed, follow_activity} = CommonAPI.follow(user2, user)

      assert_receive {:render_with_user, _, "notification.json", notif}
      assert notif.activity.id == follow_activity.id
      refute Streamer.filtered_by_user?(user, notif)
    end
  end

  test "it sends to public authenticated" do
    user = insert(:user)
    other_user = insert(:user)

    Streamer.add_socket("public", other_user)

    {:ok, activity} = CommonAPI.post(user, %{"status" => "Test"})
    assert_receive {:render_with_user, _, _, ^activity}
    refute Streamer.filtered_by_user?(user, activity)
  end

  test "works for deletions" do
    user = insert(:user)
    other_user = insert(:user)
    {:ok, activity} = CommonAPI.post(other_user, %{"status" => "Test"})

    Streamer.add_socket("public", user)

    {:ok, _} = CommonAPI.delete(activity.id, other_user)
    activity_id = activity.id
    assert_receive {:text, event}
    assert %{"event" => "delete", "payload" => ^activity_id} = Jason.decode!(event)
  end

  test "it sends to public unauthenticated" do
    user = insert(:user)

    Streamer.add_socket("public", nil)

    {:ok, activity} = CommonAPI.post(user, %{"status" => "Test"})
    activity_id = activity.id
    assert_receive {:text, event}
    assert %{"event" => "update", "payload" => payload} = Jason.decode!(event)
    assert %{"id" => ^activity_id} = Jason.decode!(payload)

    {:ok, _} = CommonAPI.delete(activity.id, user)
    assert_receive {:text, event}
    assert %{"event" => "delete", "payload" => ^activity_id} = Jason.decode!(event)
  end

  describe "thread_containment" do
    test "it filters to user if recipients invalid and thread containment is enabled" do
      Pleroma.Config.put([:instance, :skip_thread_containment], false)
      author = insert(:user)
      user = insert(:user)
      User.follow(user, author, :follow_accept)

      activity =
        insert(:note_activity,
          note:
            insert(:note,
              user: author,
              data: %{"to" => ["TEST-FFF"]}
            )
        )

      Streamer.add_socket("public", user)
      Streamer.stream("public", activity)
      assert_receive {:render_with_user, _, _, ^activity}
      assert Streamer.filtered_by_user?(user, activity)
    end

    test "it sends message if recipients invalid and thread containment is disabled" do
      Pleroma.Config.put([:instance, :skip_thread_containment], true)
      author = insert(:user)
      user = insert(:user)
      User.follow(user, author, :follow_accept)

      activity =
        insert(:note_activity,
          note:
            insert(:note,
              user: author,
              data: %{"to" => ["TEST-FFF"]}
            )
        )

      Streamer.add_socket("public", user)
      Streamer.stream("public", activity)

      assert_receive {:render_with_user, _, _, ^activity}
      refute Streamer.filtered_by_user?(user, activity)
    end

    test "it sends message if recipients invalid and thread containment is enabled but user's thread containment is disabled" do
      Pleroma.Config.put([:instance, :skip_thread_containment], false)
      author = insert(:user)
      user = insert(:user, skip_thread_containment: true)
      User.follow(user, author, :follow_accept)

      activity =
        insert(:note_activity,
          note:
            insert(:note,
              user: author,
              data: %{"to" => ["TEST-FFF"]}
            )
        )

      Streamer.add_socket("public", user)
      Streamer.stream("public", activity)

      assert_receive {:render_with_user, _, _, ^activity}
      refute Streamer.filtered_by_user?(user, activity)
    end
  end

  describe "blocks" do
    test "it filters messages involving blocked users" do
      user = insert(:user)
      blocked_user = insert(:user)
      {:ok, _user_relationship} = User.block(user, blocked_user)

      Streamer.add_socket("public", user)
      {:ok, activity} = CommonAPI.post(blocked_user, %{"status" => "Test"})
      assert_receive {:render_with_user, _, _, ^activity}
      assert Streamer.filtered_by_user?(user, activity)
    end

    test "it filters messages transitively involving blocked users" do
      blocker = insert(:user)
      blockee = insert(:user)
      friend = insert(:user)

      Streamer.add_socket("public", blocker)

      {:ok, _user_relationship} = User.block(blocker, blockee)

      {:ok, activity_one} = CommonAPI.post(friend, %{"status" => "hey! @#{blockee.nickname}"})

      assert_receive {:render_with_user, _, _, ^activity_one}
      assert Streamer.filtered_by_user?(blocker, activity_one)

      {:ok, activity_two} = CommonAPI.post(blockee, %{"status" => "hey! @#{friend.nickname}"})

      assert_receive {:render_with_user, _, _, ^activity_two}
      assert Streamer.filtered_by_user?(blocker, activity_two)

      {:ok, activity_three} = CommonAPI.post(blockee, %{"status" => "hey! @#{blocker.nickname}"})

      assert_receive {:render_with_user, _, _, ^activity_three}
      assert Streamer.filtered_by_user?(blocker, activity_three)
    end
  end

  describe "lists" do
    test "it doesn't send unwanted DMs to list" do
      user_a = insert(:user)
      user_b = insert(:user)
      user_c = insert(:user)

      {:ok, user_a} = User.follow(user_a, user_b)

      {:ok, list} = List.create("Test", user_a)
      {:ok, list} = List.follow(list, user_b)

      Streamer.add_socket("list:#{list.id}", user_a)

      {:ok, _activity} =
        CommonAPI.post(user_b, %{
          "status" => "@#{user_c.nickname} Test",
          "visibility" => "direct"
        })

      refute_receive _
    end

    test "it doesn't send unwanted private posts to list" do
      user_a = insert(:user)
      user_b = insert(:user)

      {:ok, list} = List.create("Test", user_a)
      {:ok, list} = List.follow(list, user_b)

      Streamer.add_socket("list:#{list.id}", user_a)

      {:ok, _activity} =
        CommonAPI.post(user_b, %{
          "status" => "Test",
          "visibility" => "private"
        })

      refute_receive _
    end

    test "it sends wanted private posts to list" do
      user_a = insert(:user)
      user_b = insert(:user)

      {:ok, user_a} = User.follow(user_a, user_b)

      {:ok, list} = List.create("Test", user_a)
      {:ok, list} = List.follow(list, user_b)

      Streamer.add_socket("list:#{list.id}", user_a)

      {:ok, activity} =
        CommonAPI.post(user_b, %{
          "status" => "Test",
          "visibility" => "private"
        })

      assert_receive {:render_with_user, _, _, ^activity}
      refute Streamer.filtered_by_user?(user_a, activity)
    end
  end

  describe "muted reblogs" do
    test "it filters muted reblogs" do
      user1 = insert(:user)
      user2 = insert(:user)
      user3 = insert(:user)
      CommonAPI.follow(user1, user2)
      CommonAPI.hide_reblogs(user1, user2)

      {:ok, create_activity} = CommonAPI.post(user3, %{"status" => "I'm kawen"})

      Streamer.add_socket("user", user1)
      {:ok, announce_activity, _} = CommonAPI.repeat(create_activity.id, user2)
      assert_receive {:render_with_user, _, _, ^announce_activity}
      assert Streamer.filtered_by_user?(user1, announce_activity)
    end

    test "it filters reblog notification for reblog-muted actors" do
      user1 = insert(:user)
      user2 = insert(:user)
      CommonAPI.follow(user1, user2)
      CommonAPI.hide_reblogs(user1, user2)

      {:ok, create_activity} = CommonAPI.post(user1, %{"status" => "I'm kawen"})
      Streamer.add_socket("user", user1)
      {:ok, _favorite_activity, _} = CommonAPI.repeat(create_activity.id, user2)

      assert_receive {:render_with_user, _, "notification.json", notif}
      assert Streamer.filtered_by_user?(user1, notif)
    end

    test "it send non-reblog notification for reblog-muted actors" do
      user1 = insert(:user)
      user2 = insert(:user)
      CommonAPI.follow(user1, user2)
      CommonAPI.hide_reblogs(user1, user2)

      {:ok, create_activity} = CommonAPI.post(user1, %{"status" => "I'm kawen"})
      Streamer.add_socket("user", user1)
      {:ok, _favorite_activity} = CommonAPI.favorite(user2, create_activity.id)

      assert_receive {:render_with_user, _, "notification.json", notif}
      refute Streamer.filtered_by_user?(user1, notif)
    end
  end

  test "it filters posts from muted threads" do
    user = insert(:user)
    user2 = insert(:user)
    Streamer.add_socket("user", user2)
    {:ok, user2, user, _activity} = CommonAPI.follow(user2, user)
    {:ok, activity} = CommonAPI.post(user, %{"status" => "super hot take"})
    {:ok, _} = CommonAPI.add_mute(user2, activity)
    assert_receive {:render_with_user, _, _, ^activity}
    assert Streamer.filtered_by_user?(user2, activity)
  end

  describe "direct streams" do
    setup do
      :ok
    end

    test "it sends conversation update to the 'direct' stream", %{} do
      user = insert(:user)
      another_user = insert(:user)

      Streamer.add_socket("direct", user)

      {:ok, _create_activity} =
        CommonAPI.post(another_user, %{
          "status" => "hey @#{user.nickname}",
          "visibility" => "direct"
        })

      assert_receive {:text, received_event}

      assert %{"event" => "conversation", "payload" => received_payload} =
               Jason.decode!(received_event)

      assert %{"last_status" => last_status} = Jason.decode!(received_payload)
      [participation] = Participation.for_user(user)
      assert last_status["pleroma"]["direct_conversation_id"] == participation.id
    end

    test "it doesn't send conversation update to the 'direct' stream when the last message in the conversation is deleted" do
      user = insert(:user)
      another_user = insert(:user)

      Streamer.add_socket("direct", user)

      {:ok, create_activity} =
        CommonAPI.post(another_user, %{
          "status" => "hi @#{user.nickname}",
          "visibility" => "direct"
        })

      create_activity_id = create_activity.id
      assert_receive {:render_with_user, _, _, ^create_activity}
      assert_receive {:text, received_conversation1}
      assert %{"event" => "conversation", "payload" => _} = Jason.decode!(received_conversation1)

      {:ok, _} = CommonAPI.delete(create_activity_id, another_user)

      assert_receive {:text, received_event}

      assert %{"event" => "delete", "payload" => ^create_activity_id} =
               Jason.decode!(received_event)

      refute_receive _
    end

    test "it sends conversation update to the 'direct' stream when a message is deleted" do
      user = insert(:user)
      another_user = insert(:user)
      Streamer.add_socket("direct", user)

      {:ok, create_activity} =
        CommonAPI.post(another_user, %{
          "status" => "hi @#{user.nickname}",
          "visibility" => "direct"
        })

      {:ok, create_activity2} =
        CommonAPI.post(another_user, %{
          "status" => "hi @#{user.nickname} 2",
          "in_reply_to_status_id" => create_activity.id,
          "visibility" => "direct"
        })

      assert_receive {:render_with_user, _, _, ^create_activity}
      assert_receive {:render_with_user, _, _, ^create_activity2}
      assert_receive {:text, received_conversation1}
      assert %{"event" => "conversation", "payload" => _} = Jason.decode!(received_conversation1)
      assert_receive {:text, received_conversation1}
      assert %{"event" => "conversation", "payload" => _} = Jason.decode!(received_conversation1)

      {:ok, _} = CommonAPI.delete(create_activity2.id, another_user)

      assert_receive {:text, received_event}
      assert %{"event" => "delete", "payload" => _} = Jason.decode!(received_event)

      assert_receive {:text, received_event}

      assert %{"event" => "conversation", "payload" => received_payload} =
               Jason.decode!(received_event)

      assert %{"last_status" => last_status} = Jason.decode!(received_payload)
      assert last_status["id"] == to_string(create_activity.id)
    end
  end
end
