# Pleroma: A lightweight social networking server
# Copyright © 2017-2018 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-onl

defmodule Pleroma.User.SynchronizationWorker do
  use GenServer

  def start_link do
    config = Pleroma.Config.get([:instance, :external_user_synchronization])

    if config[:enabled] do
      GenServer.start_link(__MODULE__, interval: config[:interval])
    else
      :ignore
    end
  end

  def init(opts) do
    schedule_next(opts)
    {:ok, opts}
  end

  def handle_info(:sync_follow_counters, opts) do
    Pleroma.User.sync_follow_counter()
    schedule_next(opts)
    {:noreply, opts}
  end

  defp schedule_next(opts) do
    Process.send_after(self(), :sync_follow_counters, opts[:interval])
  end
end
