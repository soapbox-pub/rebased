# Pleroma: A lightweight social networking server
# Copyright © 2017-2020 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Workers.ScheduledActivityWorker do
  @moduledoc """
  The worker to post scheduled activity.
  """

  use Pleroma.Workers.WorkerHelper, queue: "scheduled_activities"

  alias Pleroma.Config
  alias Pleroma.ScheduledActivity
  alias Pleroma.User
  alias Pleroma.Web.CommonAPI

  require Logger

  @impl Oban.Worker
  def perform(%{"activity_id" => activity_id}, _job) do
    if Config.get([ScheduledActivity, :enabled]) do
      case Pleroma.Repo.get(ScheduledActivity, activity_id) do
        %ScheduledActivity{} = scheduled_activity ->
          post_activity(scheduled_activity)

        _ ->
          Logger.error("#{__MODULE__} Couldn't find scheduled activity: #{activity_id}")
      end
    end
  end

  defp post_activity(%ScheduledActivity{user_id: user_id, params: params} = scheduled_activity) do
    with {:delete, {:ok, _}} <- {:delete, ScheduledActivity.delete(scheduled_activity)},
         {:user, %User{} = user} <- {:user, User.get_cached_by_id(user_id)},
         {:post, {:ok, _}} <- {:post, CommonAPI.post(user, params)} do
      :ok
    else
      error ->
        Logger.error(
          "#{__MODULE__} Couldn't create a status from the scheduled activity: #{inspect(error)}"
        )
    end
  end
end
