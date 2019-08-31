# Pleroma: A lightweight social networking server
# Copyright © 2017-2019 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Workers.WebPusherWorker do
  alias Pleroma.Notification
  alias Pleroma.Repo

  # Note: `max_attempts` is intended to be overridden in `new/2` call
  use Oban.Worker,
    queue: "web_push",
    max_attempts: 1

  use Pleroma.Workers.WorkerHelper, queue: "web_push"

  @impl Oban.Worker
  def perform(%{"op" => "web_push", "notification_id" => notification_id}, _job) do
    notification = Repo.get(Notification, notification_id)
    Pleroma.Web.Push.Impl.perform(notification)
  end
end
