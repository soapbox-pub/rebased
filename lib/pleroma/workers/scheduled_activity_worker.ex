# Pleroma: A lightweight social networking server
# Copyright © 2017-2021 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Workers.ScheduledActivityWorker do
  @moduledoc """
  The worker to post scheduled activity.
  """

  use Pleroma.Workers.WorkerHelper, queue: "scheduled_activities"

  alias Pleroma.Repo
  alias Pleroma.ScheduledActivity
  alias Pleroma.User

  require Logger

  @impl Oban.Worker
  def perform(%Job{args: %{"activity_id" => activity_id}}) do
    with %ScheduledActivity{} = scheduled_activity <- find_scheduled_activity(activity_id),
         %User{} = user <- find_user(scheduled_activity.user_id) do
      params = atomize_keys(scheduled_activity.params)

      Repo.transaction(fn ->
        {:ok, activity} = Pleroma.Web.CommonAPI.post(user, params)
        {:ok, _} = ScheduledActivity.delete(scheduled_activity)
        activity
      end)
    else
      {:error, :scheduled_activity_not_found} = error ->
        Logger.error("#{__MODULE__} Couldn't find scheduled activity: #{activity_id}")
        error

      {:error, :user_not_found} = error ->
        Logger.error("#{__MODULE__} Couldn't find user for scheduled activity: #{activity_id}")
        error
    end
  end

  defp find_scheduled_activity(id) do
    with nil <- Repo.get(ScheduledActivity, id) do
      {:error, :scheduled_activity_not_found}
    end
  end

  defp find_user(id) do
    with nil <- User.get_cached_by_id(id) do
      {:error, :user_not_found}
    end
  end

  defp atomize_keys(map) do
    Map.new(map, fn
      {key, value} when is_map(value) -> {String.to_existing_atom(key), atomize_keys(value)}
      {key, value} -> {String.to_existing_atom(key), value}
    end)
  end
end
