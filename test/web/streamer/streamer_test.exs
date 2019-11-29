# Pleroma: A lightweight social networking server
# Copyright © 2017-2019 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.StreamerTest do
  use Pleroma.DataCase

  import Pleroma.Factory

  alias Pleroma.Conversation.Participation
  alias Pleroma.List
  alias Pleroma.User
  alias Pleroma.Web.CommonAPI
  alias Pleroma.Web.Streamer
  alias Pleroma.Web.Streamer.StreamerSocket
  alias Pleroma.Web.Streamer.Worker

  @moduletag needs_streamer: true, capture_log: true
  clear_config_all([:instance, :skip_thread_containment])

  describe "user streams" do
    setup do
      user = insert(:user)
      notify = insert(:notification, user: user, activity: build(:note_activity))
      {:ok, %{user: user, notify: notify}}
    end

    test "it sends notify to in the 'user' stream", %{user: user, notify: notify} do
      task =
        Task.async(fn ->
          assert_receive {:text, _}, 4_000
        end)

      Streamer.add_socket(
        "user",
        %{transport_pid: task.pid, assigns: %{user: user}}
      )

      Streamer.stream("user", notify)
      Task.await(task)
    end

    test "it sends notify to in the 'user:notification' stream", %{user: user, notify: notify} do
      task =
        Task.async(fn ->
          assert_receive {:text, _}, 4_000
        end)

      Streamer.add_socket(
        "user:notification",
        %{transport_pid: task.pid, assigns: %{user: user}}
      )

      Streamer.stream("user:notification", notify)
      Task.await(task)
    end

    test "it doesn't send notify to the 'user:notification' stream when a user is blocked", %{
      user: user
    } do
      blocked = insert(:user)
      {:ok, _user_relationship} = User.block(user, blocked)

      task = Task.async(fn -> refute_receive {:text, _}, 4_000 end)

      Streamer.add_socket(
        "user:notification",
        %{transport_pid: task.pid, assigns: %{user: user}}
      )

      {:ok, activity} = CommonAPI.post(user, %{"status" => ":("})
      {:ok, notif, _} = CommonAPI.favorite(activity.id, blocked)

      Streamer.stream("user:notification", notif)
      Task.await(task)
    end

    test "it doesn't send notify to the 'user:notification' stream when a thread is muted", %{
      user: user
    } do
      user2 = insert(:user)
      task = Task.async(fn -> refute_receive {:text, _}, 4_000 end)

      Streamer.add_socket(
        "user:notification",
        %{transport_pid: task.pid, assigns: %{user: user}}
      )

      {:ok, activity} = CommonAPI.post(user, %{"status" => "super hot take"})
      {:ok, activity} = CommonAPI.add_mute(user, activity)
      {:ok, notif, _} = CommonAPI.favorite(activity.id, user2)
      Streamer.stream("user:notification", notif)
      Task.await(task)
    end

    test "it doesn't send notify to the 'user:notification' stream' when a domain is blocked", %{
      user: user
    } do
      user2 = insert(:user, %{ap_id: "https://hecking-lewd-place.com/user/meanie"})
      task = Task.async(fn -> refute_receive {:text, _}, 4_000 end)

      Streamer.add_socket(
        "user:notification",
        %{transport_pid: task.pid, assigns: %{user: user}}
      )

      {:ok, user} = User.block_domain(user, "hecking-lewd-place.com")
      {:ok, activity} = CommonAPI.post(user, %{"status" => "super hot take"})
      {:ok, notif, _} = CommonAPI.favorite(activity.id, user2)

      Streamer.stream("user:notification", notif)
      Task.await(task)
    end

    test "it sends follow activities to the 'user:notification' stream", %{
      user: user
    } do
      user2 = insert(:user)
      task = Task.async(fn -> assert_receive {:text, _}, 4_000 end)

      Streamer.add_socket(
        "user:notification",
        %{transport_pid: task.pid, assigns: %{user: user}}
      )

      {:ok, _follower, _followed, _activity} = CommonAPI.follow(user2, user)

      # We don't directly pipe the notification to the streamer as it's already
      # generated as a side effect of CommonAPI.follow().
      Task.await(task)
    end
  end

  test "it sends to public" do
    user = insert(:user)
    other_user = insert(:user)

    task =
      Task.async(fn ->
        assert_receive {:text, _}, 4_000
      end)

    fake_socket = %StreamerSocket{
      transport_pid: task.pid,
      user: user
    }

    {:ok, activity} = CommonAPI.post(other_user, %{"status" => "Test"})

    topics = %{
      "public" => [fake_socket]
    }

    Worker.push_to_socket(topics, "public", activity)

    Task.await(task)

    task =
      Task.async(fn ->
        expected_event =
          %{
            "event" => "delete",
            "payload" => activity.id
          }
          |> Jason.encode!()

        assert_receive {:text, received_event}, 4_000
        assert received_event == expected_event
      end)

    fake_socket = %StreamerSocket{
      transport_pid: task.pid,
      user: user
    }

    {:ok, activity} = CommonAPI.delete(activity.id, other_user)

    topics = %{
      "public" => [fake_socket]
    }

    Worker.push_to_socket(topics, "public", activity)

    Task.await(task)
  end

  describe "thread_containment" do
    test "it doesn't send to user if recipients invalid and thread containment is enabled" do
      Pleroma.Config.put([:instance, :skip_thread_containment], false)
      author = insert(:user)
      user = insert(:user)
      User.follow(user, author, "accept")

      activity =
        insert(:note_activity,
          note:
            insert(:note,
              user: author,
              data: %{"to" => ["TEST-FFF"]}
            )
        )

      task = Task.async(fn -> refute_receive {:text, _}, 1_000 end)
      fake_socket = %StreamerSocket{transport_pid: task.pid, user: user}
      topics = %{"public" => [fake_socket]}
      Worker.push_to_socket(topics, "public", activity)

      Task.await(task)
    end

    test "it sends message if recipients invalid and thread containment is disabled" do
      Pleroma.Config.put([:instance, :skip_thread_containment], true)
      author = insert(:user)
      user = insert(:user)
      User.follow(user, author, "accept")

      activity =
        insert(:note_activity,
          note:
            insert(:note,
              user: author,
              data: %{"to" => ["TEST-FFF"]}
            )
        )

      task = Task.async(fn -> assert_receive {:text, _}, 1_000 end)
      fake_socket = %StreamerSocket{transport_pid: task.pid, user: user}
      topics = %{"public" => [fake_socket]}
      Worker.push_to_socket(topics, "public", activity)

      Task.await(task)
    end

    test "it sends message if recipients invalid and thread containment is enabled but user's thread containment is disabled" do
      Pleroma.Config.put([:instance, :skip_thread_containment], false)
      author = insert(:user)
      user = insert(:user, skip_thread_containment: true)
      User.follow(user, author, "accept")

      activity =
        insert(:note_activity,
          note:
            insert(:note,
              user: author,
              data: %{"to" => ["TEST-FFF"]}
            )
        )

      task = Task.async(fn -> assert_receive {:text, _}, 1_000 end)
      fake_socket = %StreamerSocket{transport_pid: task.pid, user: user}
      topics = %{"public" => [fake_socket]}
      Worker.push_to_socket(topics, "public", activity)

      Task.await(task)
    end
  end

  describe "blocks" do
    test "it doesn't send messages involving blocked users" do
      user = insert(:user)
      blocked_user = insert(:user)
      {:ok, _user_relationship} = User.block(user, blocked_user)

      task =
        Task.async(fn ->
          refute_receive {:text, _}, 1_000
        end)

      fake_socket = %StreamerSocket{
        transport_pid: task.pid,
        user: user
      }

      {:ok, activity} = CommonAPI.post(blocked_user, %{"status" => "Test"})

      topics = %{
        "public" => [fake_socket]
      }

      Worker.push_to_socket(topics, "public", activity)

      Task.await(task)
    end

    test "it doesn't send messages transitively involving blocked users" do
      blocker = insert(:user)
      blockee = insert(:user)
      friend = insert(:user)

      task =
        Task.async(fn ->
          refute_receive {:text, _}, 1_000
        end)

      fake_socket = %StreamerSocket{
        transport_pid: task.pid,
        user: blocker
      }

      topics = %{
        "public" => [fake_socket]
      }

      {:ok, _user_relationship} = User.block(blocker, blockee)

      {:ok, activity_one} = CommonAPI.post(friend, %{"status" => "hey! @#{blockee.nickname}"})

      Worker.push_to_socket(topics, "public", activity_one)

      {:ok, activity_two} = CommonAPI.post(blockee, %{"status" => "hey! @#{friend.nickname}"})

      Worker.push_to_socket(topics, "public", activity_two)

      {:ok, activity_three} = CommonAPI.post(blockee, %{"status" => "hey! @#{blocker.nickname}"})

      Worker.push_to_socket(topics, "public", activity_three)

      Task.await(task)
    end
  end

  test "it doesn't send unwanted DMs to list" do
    user_a = insert(:user)
    user_b = insert(:user)
    user_c = insert(:user)

    {:ok, user_a} = User.follow(user_a, user_b)

    {:ok, list} = List.create("Test", user_a)
    {:ok, list} = List.follow(list, user_b)

    task =
      Task.async(fn ->
        refute_receive {:text, _}, 1_000
      end)

    fake_socket = %StreamerSocket{
      transport_pid: task.pid,
      user: user_a
    }

    {:ok, activity} =
      CommonAPI.post(user_b, %{
        "status" => "@#{user_c.nickname} Test",
        "visibility" => "direct"
      })

    topics = %{
      "list:#{list.id}" => [fake_socket]
    }

    Worker.handle_call({:stream, "list", activity}, self(), topics)

    Task.await(task)
  end

  test "it doesn't send unwanted private posts to list" do
    user_a = insert(:user)
    user_b = insert(:user)

    {:ok, list} = List.create("Test", user_a)
    {:ok, list} = List.follow(list, user_b)

    task =
      Task.async(fn ->
        refute_receive {:text, _}, 1_000
      end)

    fake_socket = %StreamerSocket{
      transport_pid: task.pid,
      user: user_a
    }

    {:ok, activity} =
      CommonAPI.post(user_b, %{
        "status" => "Test",
        "visibility" => "private"
      })

    topics = %{
      "list:#{list.id}" => [fake_socket]
    }

    Worker.handle_call({:stream, "list", activity}, self(), topics)

    Task.await(task)
  end

  test "it sends wanted private posts to list" do
    user_a = insert(:user)
    user_b = insert(:user)

    {:ok, user_a} = User.follow(user_a, user_b)

    {:ok, list} = List.create("Test", user_a)
    {:ok, list} = List.follow(list, user_b)

    task =
      Task.async(fn ->
        assert_receive {:text, _}, 1_000
      end)

    fake_socket = %StreamerSocket{
      transport_pid: task.pid,
      user: user_a
    }

    {:ok, activity} =
      CommonAPI.post(user_b, %{
        "status" => "Test",
        "visibility" => "private"
      })

    Streamer.add_socket(
      "list:#{list.id}",
      fake_socket
    )

    Worker.handle_call({:stream, "list", activity}, self(), %{})

    Task.await(task)
  end

  test "it doesn't send muted reblogs" do
    user1 = insert(:user)
    user2 = insert(:user)
    user3 = insert(:user)
    CommonAPI.hide_reblogs(user1, user2)

    task =
      Task.async(fn ->
        refute_receive {:text, _}, 1_000
      end)

    fake_socket = %StreamerSocket{
      transport_pid: task.pid,
      user: user1
    }

    {:ok, create_activity} = CommonAPI.post(user3, %{"status" => "I'm kawen"})
    {:ok, announce_activity, _} = CommonAPI.repeat(create_activity.id, user2)

    topics = %{
      "public" => [fake_socket]
    }

    Worker.push_to_socket(topics, "public", announce_activity)

    Task.await(task)
  end

  test "it doesn't send posts from muted threads" do
    user = insert(:user)
    user2 = insert(:user)
    {:ok, user2, user, _activity} = CommonAPI.follow(user2, user)

    {:ok, activity} = CommonAPI.post(user, %{"status" => "super hot take"})

    {:ok, activity} = CommonAPI.add_mute(user2, activity)

    task = Task.async(fn -> refute_receive {:text, _}, 4_000 end)

    Process.sleep(4000)

    Streamer.add_socket(
      "user",
      %{transport_pid: task.pid, assigns: %{user: user2}}
    )

    Streamer.stream("user", activity)
    Task.await(task)
  end

  describe "direct streams" do
    setup do
      :ok
    end

    test "it sends conversation update to the 'direct' stream", %{} do
      user = insert(:user)
      another_user = insert(:user)

      task =
        Task.async(fn ->
          assert_receive {:text, received_event}, 4_000

          assert %{"event" => "conversation", "payload" => received_payload} =
                   Jason.decode!(received_event)

          assert %{"last_status" => last_status} = Jason.decode!(received_payload)
          [participation] = Participation.for_user(user)
          assert last_status["pleroma"]["direct_conversation_id"] == participation.id
        end)

      Streamer.add_socket(
        "direct",
        %{transport_pid: task.pid, assigns: %{user: user}}
      )

      {:ok, _create_activity} =
        CommonAPI.post(another_user, %{
          "status" => "hey @#{user.nickname}",
          "visibility" => "direct"
        })

      Task.await(task)
    end

    test "it doesn't send conversation update to the 'direct' stream when the last message in the conversation is deleted" do
      user = insert(:user)
      another_user = insert(:user)

      {:ok, create_activity} =
        CommonAPI.post(another_user, %{
          "status" => "hi @#{user.nickname}",
          "visibility" => "direct"
        })

      task =
        Task.async(fn ->
          assert_receive {:text, received_event}, 4_000
          assert %{"event" => "delete", "payload" => _} = Jason.decode!(received_event)

          refute_receive {:text, _}, 4_000
        end)

      Process.sleep(1000)

      Streamer.add_socket(
        "direct",
        %{transport_pid: task.pid, assigns: %{user: user}}
      )

      {:ok, _} = CommonAPI.delete(create_activity.id, another_user)

      Task.await(task)
    end

    test "it sends conversation update to the 'direct' stream when a message is deleted" do
      user = insert(:user)
      another_user = insert(:user)

      {:ok, create_activity} =
        CommonAPI.post(another_user, %{
          "status" => "hi @#{user.nickname}",
          "visibility" => "direct"
        })

      {:ok, create_activity2} =
        CommonAPI.post(another_user, %{
          "status" => "hi @#{user.nickname}",
          "in_reply_to_status_id" => create_activity.id,
          "visibility" => "direct"
        })

      task =
        Task.async(fn ->
          assert_receive {:text, received_event}, 4_000
          assert %{"event" => "delete", "payload" => _} = Jason.decode!(received_event)

          assert_receive {:text, received_event}, 4_000

          assert %{"event" => "conversation", "payload" => received_payload} =
                   Jason.decode!(received_event)

          assert %{"last_status" => last_status} = Jason.decode!(received_payload)
          assert last_status["id"] == to_string(create_activity.id)
        end)

      Process.sleep(1000)

      Streamer.add_socket(
        "direct",
        %{transport_pid: task.pid, assigns: %{user: user}}
      )

      {:ok, _} = CommonAPI.delete(create_activity2.id, another_user)

      Task.await(task)
    end
  end
end
