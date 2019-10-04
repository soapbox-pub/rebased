# Pleroma: A lightweight social networking server
# Copyright © 2017-2019 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.Streamer.StreamerSocket do
  defstruct transport_pid: nil, user: nil

  alias Pleroma.User
  alias Pleroma.Web.Streamer.StreamerSocket

  def from_socket(%{
        transport_pid: transport_pid,
        assigns: %{user: nil}
      }) do
    %StreamerSocket{
      transport_pid: transport_pid
    }
  end

  def from_socket(%{
        transport_pid: transport_pid,
        assigns: %{user: %User{} = user}
      }) do
    %StreamerSocket{
      transport_pid: transport_pid,
      user: user
    }
  end

  def from_socket(%{transport_pid: transport_pid}) do
    %StreamerSocket{
      transport_pid: transport_pid
    }
  end
end
