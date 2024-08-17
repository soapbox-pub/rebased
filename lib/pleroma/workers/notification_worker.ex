# Pleroma: A lightweight social networking server
# Copyright © 2017-2022 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Workers.NotificationWorker do
  @moduledoc """
  Creates notifications for an Activity.
  """
  use Oban.Worker, queue: :notifications

  alias Pleroma.Activity
  alias Pleroma.Notification

  @impl true
  @spec perform(Oban.Job.t()) :: {:error, :activity_not_found} | {:ok, [Pleroma.Notification.t()]}
  def perform(%Job{args: %{"op" => "create", "activity_id" => activity_id}}) do
    with %Activity{} = activity <- find_activity(activity_id),
         {:ok, notifications} <- Notification.create_notifications(activity) do
      Notification.stream(notifications)
    end
  end

  defp find_activity(activity_id) do
    with nil <- Activity.get_by_id(activity_id) do
      {:error, :activity_not_found}
    end
  end
end
