# Pleroma: A lightweight social networking server
# Copyright © 2017-2019 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Daemons.ScheduledActivityDaemon do
  @moduledoc """
  Sends scheduled activities to the job queue.
  """

  alias Pleroma.Config
  alias Pleroma.ScheduledActivity
  alias Pleroma.User
  alias Pleroma.Web.CommonAPI

  use GenServer
  require Logger

  @schedule_interval :timer.minutes(1)

  def start_link(_) do
    GenServer.start_link(__MODULE__, nil)
  end

  def init(_) do
    if Config.get([ScheduledActivity, :enabled]) do
      schedule_next()
      {:ok, nil}
    else
      :ignore
    end
  end

  def perform(:execute, scheduled_activity_id) do
    try do
      {:ok, scheduled_activity} = ScheduledActivity.delete(scheduled_activity_id)
      %User{} = user = User.get_cached_by_id(scheduled_activity.user_id)
      {:ok, _result} = CommonAPI.post(user, scheduled_activity.params)
    rescue
      error ->
        Logger.error(
          "#{__MODULE__} Couldn't create a status from the scheduled activity: #{inspect(error)}"
        )
    end
  end

  def handle_info(:perform, state) do
    ScheduledActivity.due_activities(@schedule_interval)
    |> Enum.each(fn scheduled_activity ->
      Pleroma.Workers.ScheduledActivityWorker.enqueue(
        "execute",
        %{"activity_id" => scheduled_activity.id}
      )
    end)

    schedule_next()
    {:noreply, state}
  end

  defp schedule_next do
    Process.send_after(self(), :perform, @schedule_interval)
  end
end
