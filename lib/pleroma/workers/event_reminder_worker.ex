# Pleroma: A lightweight social networking server
# Copyright © 2017-2022 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Workers.EventReminderWorker do
  @moduledoc """
  Generates notifications for upcoming events.
  """
  use Pleroma.Workers.WorkerHelper, queue: "event_notifications"

  alias Pleroma.Activity
  alias Pleroma.Notification
  alias Pleroma.Object

  @impl Oban.Worker
  def perform(%Job{args: %{"op" => "event_reminder", "activity_id" => activity_id}}) do
    with %Activity{} = activity <- find_event_activity(activity_id) do
      Notification.create_event_notifications(activity)
    end
  end

  defp find_event_activity(activity_id) do
    with nil <- Activity.get_by_id(activity_id) do
      {:error, :event_activity_not_found}
    end
  end

  def schedule_event_reminder(%Activity{data: %{"type" => "Create"}, id: activity_id} = activity) do
    with %Object{data: %{"type" => "Event", "startTime" => start_time}} <-
           Object.normalize(activity),
         {:ok, start_time, _} <- DateTime.from_iso8601(start_time),
         :gt <-
           DateTime.compare(
             start_time |> DateTime.add(60 * 60 * -2, :second),
             DateTime.utc_now()
           ) do
      %{
        op: "event_reminder",
        activity_id: activity_id
      }
      |> new(scheduled_at: start_time |> DateTime.add(60 * 60 * -2, :second))
      |> Oban.insert()
    else
      _ -> {:error, activity}
    end
  end

  def schedule_event_reminder(activity), do: {:error, activity}
end
