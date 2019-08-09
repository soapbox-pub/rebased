# Pleroma: A lightweight social networking server
# Copyright © 2017-2019 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Workers.Subscriber do
  alias Pleroma.Repo
  alias Pleroma.Web.Websub
  alias Pleroma.Web.Websub.WebsubClientSubscription

  require Logger

  # Note: `max_attempts` is intended to be overridden in `new/1` call
  use Oban.Worker,
    queue: "federator_outgoing",
    max_attempts: Pleroma.Config.get([:workers, :retries, :compile_time_default])

  @impl Oban.Worker
  def perform(%{"op" => "refresh_subscriptions"}) do
    Websub.refresh_subscriptions()
    # Schedule the next run in 6 hours
    Pleroma.Web.Federator.refresh_subscriptions(schedule_in: 3600 * 6)
  end

  def perform(%{"op" => "request_subscription", "websub_id" => websub_id}) do
    websub = Repo.get(WebsubClientSubscription, websub_id)
    Logger.debug("Refreshing #{websub.topic}")

    with {:ok, websub} <- Websub.request_subscription(websub) do
      Logger.debug("Successfully refreshed #{websub.topic}")
    else
      _e -> Logger.debug("Couldn't refresh #{websub.topic}")
    end
  end

  def perform(%{"op" => "verify_websub", "websub_id" => websub_id}) do
    websub = Repo.get(WebsubClientSubscription, websub_id)

    Logger.debug(fn ->
      "Running WebSub verification for #{websub.id} (#{websub.topic}, #{websub.callback})"
    end)

    Websub.verify(websub)
  end
end
