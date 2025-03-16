# Pleroma: A lightweight social networking server
# Copyright © 2017-2022 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Workers.PollWorker do
  @moduledoc """
  Generates notifications when a poll ends.
  """
  use Oban.Worker, queue: :background

  alias Pleroma.Activity
  alias Pleroma.Notification
  alias Pleroma.Object
  alias Pleroma.Object.Fetcher

  @stream_out_impl Pleroma.Config.get(
                     [__MODULE__, :stream_out],
                     Pleroma.Web.ActivityPub.ActivityPub
                   )

  @impl true
  def perform(%Job{args: %{"op" => "poll_end", "activity_id" => activity_id}}) do
    with {_, %Activity{} = activity} <- {:activity, Activity.get_by_id(activity_id)},
         {:ok, notifications} <- Notification.create_poll_notifications(activity) do
      unless activity.local do
        # Schedule a final refresh
        __MODULE__.new(%{"op" => "refresh", "activity_id" => activity_id})
        |> Oban.insert()
      end

      Notification.stream(notifications)
    else
      {:activity, nil} -> {:cancel, :poll_activity_not_found}
      e -> {:error, e}
    end
  end

  def perform(%Job{args: %{"op" => "refresh", "activity_id" => activity_id}}) do
    with {_, %Activity{object: object}} <-
           {:activity, Activity.get_by_id_with_object(activity_id)},
         {_, {:ok, _object}} <- {:refetch, Fetcher.refetch_object(object)} do
      stream_update(activity_id)

      :ok
    else
      {:activity, nil} -> {:cancel, :poll_activity_not_found}
      {:refetch, _} = e -> {:cancel, e}
    end
  end

  @impl true
  def timeout(_job), do: :timer.seconds(5)

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

  defp stream_update(activity_id) do
    Activity.get_by_id(activity_id)
    |> Activity.normalize()
    |> @stream_out_impl.stream_out()
  end
end
