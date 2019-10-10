# Pleroma: A lightweight social networking server
# Copyright © 2017-2019 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Workers.WebPusherWorker do
  alias Pleroma.Notification
  alias Pleroma.Repo

  use Pleroma.Workers.WorkerHelper, queue: "web_push"

  @impl Oban.Worker
  def perform(%{"op" => "web_push", "notification_id" => notification_id}, _job) do
    notification =
      Notification
      |> Repo.get(notification_id)
      |> Repo.preload([:activity])

    Pleroma.Web.Push.Impl.perform(notification)
  end
end
