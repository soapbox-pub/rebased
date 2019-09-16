# Pleroma: A lightweight social networking server
# Copyright © 2017-2019 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.StateTest do
  use Pleroma.DataCase

  import Pleroma.Factory
  alias Pleroma.Web.Streamer
  alias Pleroma.Web.Streamer.StreamerSocket

  @moduletag needs_streamer: true

  describe "sockets" do
    setup do
      user = insert(:user)
      user2 = insert(:user)
      {:ok, %{user: user, user2: user2}}
    end

    test "it can add a socket", %{user: user} do
      Streamer.add_socket("public", %{transport_pid: 1, assigns: %{user: user}})

      assert(%{"public" => [%StreamerSocket{transport_pid: 1}]} = Streamer.get_sockets())
    end

    test "it can add multiple sockets per user", %{user: user} do
      Streamer.add_socket("public", %{transport_pid: 1, assigns: %{user: user}})
      Streamer.add_socket("public", %{transport_pid: 2, assigns: %{user: user}})

      assert(
        %{
          "public" => [
            %StreamerSocket{transport_pid: 2},
            %StreamerSocket{transport_pid: 1}
          ]
        } = Streamer.get_sockets()
      )
    end

    test "it will not add a duplicate socket", %{user: user} do
      Streamer.add_socket("activity", %{transport_pid: 1, assigns: %{user: user}})
      Streamer.add_socket("activity", %{transport_pid: 1, assigns: %{user: user}})

      assert(
        %{
          "activity" => [
            %StreamerSocket{transport_pid: 1}
          ]
        } = Streamer.get_sockets()
      )
    end
  end
end
