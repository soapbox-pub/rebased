# Pleroma: A lightweight social networking server
# Copyright © 2017-2019 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.PingTest do
  use Pleroma.DataCase

  import Pleroma.Factory
  alias Pleroma.Web.Streamer

  setup do
    start_supervised({Streamer.supervisor(), [ping_interval: 30]})

    :ok
  end

  describe "sockets" do
    setup do
      user = insert(:user)
      {:ok, %{user: user}}
    end

    test "it sends pings", %{user: user} do
      task =
        Task.async(fn ->
          assert_receive {:text, received_event}, 40
          assert_receive {:text, received_event}, 40
          assert_receive {:text, received_event}, 40
        end)

      Streamer.add_socket("public", %{transport_pid: task.pid, assigns: %{user: user}})

      Task.await(task)
    end
  end
end
