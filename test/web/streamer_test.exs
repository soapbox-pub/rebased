# Pleroma: A lightweight social networking server
# Copyright © 2017-2018 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.StreamerTest do
  use Pleroma.DataCase

  alias Pleroma.List
  alias Pleroma.User
  alias Pleroma.Web.CommonAPI
  alias Pleroma.Web.Streamer
  import Pleroma.Factory

  setup do
    skip_thread_containment = Pleroma.Config.get([:instance, :skip_thread_containment])

    on_exit(fn ->
      Pleroma.Config.put([:instance, :skip_thread_containment], skip_thread_containment)
    end)

    :ok
  end

  test "it sends to public" do
    user = insert(:user)
    other_user = insert(:user)

    task =
      Task.async(fn ->
        assert_receive {:text, _}, 4_000
      end)

    fake_socket = %{
      transport_pid: task.pid,
      assigns: %{
        user: user
      }
    }

    {:ok, activity} = CommonAPI.post(other_user, %{"status" => "Test"})

    topics = %{
      "public" => [fake_socket]
    }

    Streamer.push_to_socket(topics, "public", activity)

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

    fake_socket = %{
      transport_pid: task.pid,
      assigns: %{
        user: user
      }
    }

    {:ok, activity} = CommonAPI.delete(activity.id, other_user)

    topics = %{
      "public" => [fake_socket]
    }

    Streamer.push_to_socket(topics, "public", activity)

    Task.await(task)
  end

  describe "thread_containment" do
    test "it doesn't send to user if recipients invalid and thread containment is enabled" do
      Pleroma.Config.put([:instance, :skip_thread_containment], false)
      author = insert(:user)
      user = insert(:user, following: [author.ap_id])

      activity =
        insert(:note_activity,
          note:
            insert(:note,
              user: author,
              data: %{"to" => ["TEST-FFF"]}
            )
        )

      task = Task.async(fn -> refute_receive {:text, _}, 1_000 end)
      fake_socket = %{transport_pid: task.pid, assigns: %{user: user}}
      topics = %{"public" => [fake_socket]}
      Streamer.push_to_socket(topics, "public", activity)

      Task.await(task)
    end

    test "it sends message if recipients invalid and thread containment is disabled" do
      Pleroma.Config.put([:instance, :skip_thread_containment], true)
      author = insert(:user)
      user = insert(:user, following: [author.ap_id])

      activity =
        insert(:note_activity,
          note:
            insert(:note,
              user: author,
              data: %{"to" => ["TEST-FFF"]}
            )
        )

      task = Task.async(fn -> assert_receive {:text, _}, 1_000 end)
      fake_socket = %{transport_pid: task.pid, assigns: %{user: user}}
      topics = %{"public" => [fake_socket]}
      Streamer.push_to_socket(topics, "public", activity)

      Task.await(task)
    end

    test "it sends message if recipients invalid and thread containment is enabled but user's thread containment is disabled" do
      Pleroma.Config.put([:instance, :skip_thread_containment], false)
      author = insert(:user)
      user = insert(:user, following: [author.ap_id], info: %{skip_thread_containment: true})

      activity =
        insert(:note_activity,
          note:
            insert(:note,
              user: author,
              data: %{"to" => ["TEST-FFF"]}
            )
        )

      task = Task.async(fn -> assert_receive {:text, _}, 1_000 end)
      fake_socket = %{transport_pid: task.pid, assigns: %{user: user}}
      topics = %{"public" => [fake_socket]}
      Streamer.push_to_socket(topics, "public", activity)

      Task.await(task)
    end
  end

  test "it doesn't send to blocked users" do
    user = insert(:user)
    blocked_user = insert(:user)
    {:ok, user} = User.block(user, blocked_user)

    task =
      Task.async(fn ->
        refute_receive {:text, _}, 1_000
      end)

    fake_socket = %{
      transport_pid: task.pid,
      assigns: %{
        user: user
      }
    }

    {:ok, activity} = CommonAPI.post(blocked_user, %{"status" => "Test"})

    topics = %{
      "public" => [fake_socket]
    }

    Streamer.push_to_socket(topics, "public", activity)

    Task.await(task)
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

    fake_socket = %{
      transport_pid: task.pid,
      assigns: %{
        user: user_a
      }
    }

    {:ok, activity} =
      CommonAPI.post(user_b, %{
        "status" => "@#{user_c.nickname} Test",
        "visibility" => "direct"
      })

    topics = %{
      "list:#{list.id}" => [fake_socket]
    }

    Streamer.handle_cast(%{action: :stream, topic: "list", item: activity}, topics)

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

    fake_socket = %{
      transport_pid: task.pid,
      assigns: %{
        user: user_a
      }
    }

    {:ok, activity} =
      CommonAPI.post(user_b, %{
        "status" => "Test",
        "visibility" => "private"
      })

    topics = %{
      "list:#{list.id}" => [fake_socket]
    }

    Streamer.handle_cast(%{action: :stream, topic: "list", item: activity}, topics)

    Task.await(task)
  end

  test "it send wanted private posts to list" do
    user_a = insert(:user)
    user_b = insert(:user)

    {:ok, user_a} = User.follow(user_a, user_b)

    {:ok, list} = List.create("Test", user_a)
    {:ok, list} = List.follow(list, user_b)

    task =
      Task.async(fn ->
        assert_receive {:text, _}, 1_000
      end)

    fake_socket = %{
      transport_pid: task.pid,
      assigns: %{
        user: user_a
      }
    }

    {:ok, activity} =
      CommonAPI.post(user_b, %{
        "status" => "Test",
        "visibility" => "private"
      })

    topics = %{
      "list:#{list.id}" => [fake_socket]
    }

    Streamer.handle_cast(%{action: :stream, topic: "list", item: activity}, topics)

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

    fake_socket = %{
      transport_pid: task.pid,
      assigns: %{
        user: user1
      }
    }

    {:ok, create_activity} = CommonAPI.post(user3, %{"status" => "I'm kawen"})
    {:ok, announce_activity, _} = CommonAPI.repeat(create_activity.id, user2)

    topics = %{
      "public" => [fake_socket]
    }

    Streamer.push_to_socket(topics, "public", announce_activity)

    Task.await(task)
  end
end
