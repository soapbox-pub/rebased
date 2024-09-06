# Pleroma: A lightweight social networking server
# Copyright © 2017-2022 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Workers.WebPusherWorker do
  alias Pleroma.Notification
  alias Pleroma.Repo
  alias Pleroma.Web.Push.Impl

  use Oban.Worker, queue: :web_push, unique: [period: :infinity]

  @impl true
  def perform(%Job{args: %{"op" => "web_push", "notification_id" => notification_id}}) do
    notification =
      Notification
      |> Repo.get(notification_id)
      |> Repo.preload([:activity, :user])

    Impl.build(notification)
    |> Enum.each(&Impl.deliver(&1))
  end

  @impl true
  def timeout(_job), do: :timer.seconds(5)
end
