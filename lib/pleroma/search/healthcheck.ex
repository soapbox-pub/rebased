# Pleroma: A lightweight social networking server
# Copyright © 2017-2024 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only
defmodule Pleroma.Search.Healthcheck do
  @doc """
  Monitors health of search backend to control processing of events based on health and availability.
  """
  use GenServer
  require Logger

  @queue :search_indexing
  @tick :timer.seconds(5)
  @timeout :timer.seconds(2)

  def start_link(_) do
    GenServer.start_link(__MODULE__, [], name: __MODULE__)
  end

  @impl true
  def init(_) do
    state = %{healthy: false}
    {:ok, state, {:continue, :start}}
  end

  @impl true
  def handle_continue(:start, state) do
    tick()
    {:noreply, state}
  end

  @impl true
  def handle_info(:check, state) do
    urls = Pleroma.Search.healthcheck_endpoints()

    new_state =
      if check(urls) do
        Oban.resume_queue(queue: @queue)
        Map.put(state, :healthy, true)
      else
        Oban.pause_queue(queue: @queue)
        Map.put(state, :healthy, false)
      end

    maybe_log_state_change(state, new_state)

    tick()
    {:noreply, new_state}
  end

  @impl true
  def handle_call(:state, _from, state) do
    {:reply, state, state, :hibernate}
  end

  def state, do: GenServer.call(__MODULE__, :state)

  def check([]), do: true

  def check(urls) when is_list(urls) do
    Enum.all?(
      urls,
      fn url ->
        case Pleroma.HTTP.get(url, [], recv_timeout: @timeout) do
          {:ok, %{status: 200}} -> true
          _ -> false
        end
      end
    )
  end

  def check(_), do: true

  defp tick do
    Process.send_after(self(), :check, @tick)
  end

  defp maybe_log_state_change(%{healthy: true}, %{healthy: false}) do
    Logger.error("Pausing Oban queue #{@queue} due to search backend healthcheck failure")
  end

  defp maybe_log_state_change(%{healthy: false}, %{healthy: true}) do
    Logger.info("Resuming Oban queue #{@queue} due to search backend healthcheck pass")
  end

  defp maybe_log_state_change(_, _), do: :ok
end
