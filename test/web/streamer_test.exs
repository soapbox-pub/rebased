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
end
