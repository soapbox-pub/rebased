# Pleroma: A lightweight social networking server
# Copyright © 2017-2019 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Workers.SubscriberWorker do
  alias Pleroma.Repo
  alias Pleroma.Web.Federator
  alias Pleroma.Web.Websub

  use Pleroma.Workers.WorkerHelper, queue: "federator_outgoing"

  @impl Oban.Worker
  def perform(%{"op" => "refresh_subscriptions"}, _job) do
    Federator.perform(:refresh_subscriptions)
  end

  def perform(%{"op" => "request_subscription", "websub_id" => websub_id}, _job) do
    websub = Repo.get(Websub.WebsubClientSubscription, websub_id)
    Federator.perform(:request_subscription, websub)
  end

  def perform(%{"op" => "verify_websub", "websub_id" => websub_id}, _job) do
    websub = Repo.get(Websub.WebsubServerSubscription, websub_id)
    Federator.perform(:verify_websub, websub)
  end
end
