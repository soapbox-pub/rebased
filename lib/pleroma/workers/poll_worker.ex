# Pleroma: A lightweight social networking server
# Copyright © 2017-2022 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Workers.PollWorker do
  @moduledoc """
  Generates notifications when a poll ends.
  """
  use Pleroma.Workers.WorkerHelper, queue: "poll_notifications"

  alias Pleroma.Activity
  alias Pleroma.Notification
  alias Pleroma.Object

  @impl Oban.Worker
  def perform(%Job{args: %{"op" => "poll_end", "activity_id" => activity_id}}) do
    with %Activity{} = activity <- find_poll_activity(activity_id) do
      Notification.create_poll_notifications(activity)
    end
  end

  @impl Oban.Worker
  def timeout(_job), do: :timer.seconds(5)

  defp find_poll_activity(activity_id) do
    with nil <- Activity.get_by_id(activity_id) do
      {:error, :poll_activity_not_found}
    end
  end

  def schedule_poll_end(%Activity{data: %{"type" => "Create"}, id: activity_id} = activity) do
    with %Object{data: %{"type" => "Question", "closed" => closed}} when is_binary(closed) <-
           Object.normalize(activity),
         {:ok, end_time} <- NaiveDateTime.from_iso8601(closed),
         :gt <- NaiveDateTime.compare(end_time, NaiveDateTime.utc_now()) do
      %{
        op: "poll_end",
        activity_id: activity_id
      }
      |> new(scheduled_at: end_time)
      |> Oban.insert()
    else
      _ -> {:error, activity}
    end
  end

  def schedule_poll_end(activity), do: {:error, activity}
end
