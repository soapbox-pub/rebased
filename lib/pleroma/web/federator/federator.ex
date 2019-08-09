# Pleroma: A lightweight social networking server
# Copyright © 2017-2019 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.Federator do
  alias Pleroma.Workers.Publisher, as: PublisherWorker
  alias Pleroma.Workers.Receiver, as: ReceiverWorker
  alias Pleroma.Workers.Subscriber, as: SubscriberWorker

  require Logger

  def init do
    # 1 minute
    refresh_subscriptions(schedule_in: 60)
  end

  @doc "Addresses [memory leaks on recursive replies fetching](https://git.pleroma.social/pleroma/pleroma/issues/161)"
  # credo:disable-for-previous-line Credo.Check.Readability.MaxLineLength
  def allowed_incoming_reply_depth?(depth) do
    max_replies_depth = Pleroma.Config.get([:instance, :federation_incoming_replies_max_depth])

    if max_replies_depth do
      (depth || 1) <= max_replies_depth
    else
      true
    end
  end

  # Client API

  def incoming_doc(doc) do
    %{"op" => "incoming_doc", "body" => doc}
    |> ReceiverWorker.new(worker_args(:federator_incoming))
    |> Pleroma.Repo.insert()
  end

  def incoming_ap_doc(params) do
    %{"op" => "incoming_ap_doc", "params" => params}
    |> ReceiverWorker.new(worker_args(:federator_incoming))
    |> Pleroma.Repo.insert()
  end

  def publish(%{id: "pleroma:fakeid"} = activity) do
    PublisherWorker.perform_publish(activity)
  end

  def publish(activity) do
    %{"op" => "publish", "activity_id" => activity.id}
    |> PublisherWorker.new(worker_args(:federator_outgoing))
    |> Pleroma.Repo.insert()
  end

  def verify_websub(websub) do
    %{"op" => "verify_websub", "websub_id" => websub.id}
    |> SubscriberWorker.new(worker_args(:federator_outgoing))
    |> Pleroma.Repo.insert()
  end

  def request_subscription(websub) do
    %{"op" => "request_subscription", "websub_id" => websub.id}
    |> SubscriberWorker.new(worker_args(:federator_outgoing))
    |> Pleroma.Repo.insert()
  end

  def refresh_subscriptions(worker_args \\ []) do
    %{"op" => "refresh_subscriptions"}
    |> SubscriberWorker.new(worker_args ++ [max_attempts: 1] ++ worker_args(:federator_outgoing))
    |> Pleroma.Repo.insert()
  end

  defp worker_args(queue) do
    if max_attempts = Pleroma.Config.get([:workers, :retries, queue]) do
      [max_attempts: max_attempts]
    else
      []
    end
  end
end
