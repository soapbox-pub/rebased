# Pleroma: A lightweight social networking server
# Copyright © 2017-2019 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Workers.Cron.PurgeExpiredActivitiesWorker do
  @moduledoc """
  The worker to purge expired activities.
  """

  use Oban.Worker, queue: "activity_expiration"

  alias Pleroma.Activity
  alias Pleroma.ActivityExpiration
  alias Pleroma.Config
  alias Pleroma.User
  alias Pleroma.Web.CommonAPI

  require Logger

  @interval :timer.minutes(1)

  @impl Oban.Worker
  def perform(_opts, _job) do
    if Config.get([ActivityExpiration, :enabled]) do
      Enum.each(ActivityExpiration.due_expirations(@interval), &delete_activity/1)
    end
  end

  def delete_activity(expiration) do
    try do
      activity = Activity.get_by_id_with_object(expiration.activity_id)
      user = User.get_by_ap_id(activity.object.data["actor"])
      CommonAPI.delete(activity.id, user)
    rescue
      error ->
        Logger.error("#{__MODULE__} Couldn't delete expired activity: #{inspect(error)}")
    end
  end
end
