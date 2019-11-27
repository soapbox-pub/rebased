# Pleroma: A lightweight social networking server
# Copyright © 2017-2019 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Workers.Cron.ScheduledActivityWorker do
  @moduledoc """
  The worker to post scheduled actvities.
  """

  use Oban.Worker, queue: "scheduled_activities"
  alias Pleroma.Config
  alias Pleroma.ScheduledActivity
  alias Pleroma.User
  alias Pleroma.Web.CommonAPI

  require Logger

  @schedule_interval :timer.minutes(1)

  @impl Oban.Worker
  def perform(_opts, _job) do
    if Config.get([ScheduledActivity, :enabled]) do
      @schedule_interval
      |> ScheduledActivity.due_activities()
      |> Enum.each(&post_activity/1)
    end
  end

  def post_activity(scheduled_activity) do
    try do
      {:ok, scheduled_activity} = ScheduledActivity.delete(scheduled_activity)
      %User{} = user = User.get_cached_by_id(scheduled_activity.user_id)
      {:ok, _result} = CommonAPI.post(user, scheduled_activity.params)
    rescue
      error ->
        Logger.error(
          "#{__MODULE__} Couldn't create a status from the scheduled activity: #{inspect(error)}"
        )
    end
  end
end
