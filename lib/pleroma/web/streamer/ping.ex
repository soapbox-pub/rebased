# Pleroma: A lightweight social networking server
# Copyright © 2017-2019 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.Streamer.Ping do
  use GenServer
  require Logger

  alias Pleroma.Web.Streamer.State
  alias Pleroma.Web.Streamer.StreamerSocket

  @keepalive_interval :timer.seconds(30)

  def start_link(opts) do
    ping_interval = Keyword.get(opts, :ping_interval, @keepalive_interval)
    GenServer.start_link(__MODULE__, %{ping_interval: ping_interval}, name: __MODULE__)
  end

  def init(%{ping_interval: ping_interval} = args) do
    Process.send_after(self(), :ping, ping_interval)
    {:ok, args}
  end

  def handle_info(:ping, %{ping_interval: ping_interval} = state) do
    State.get_sockets()
    |> Map.values()
    |> List.flatten()
    |> Enum.each(fn %StreamerSocket{transport_pid: transport_pid} ->
      Logger.debug("Sending keepalive ping")
      send(transport_pid, {:text, ""})
    end)

    Process.send_after(self(), :ping, ping_interval)

    {:noreply, state}
  end
end
