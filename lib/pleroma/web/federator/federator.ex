# Pleroma: A lightweight social networking server
# Copyright © 2017-2019 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.Federator do
  alias Pleroma.Activity
  alias Pleroma.Object.Containment
  alias Pleroma.User
  alias Pleroma.Web.ActivityPub.ActivityPub
  alias Pleroma.Web.ActivityPub.Transmogrifier
  alias Pleroma.Web.ActivityPub.Utils
  alias Pleroma.Web.ActivityPub.Visibility
  alias Pleroma.Web.Federator.Publisher
  alias Pleroma.Web.Federator.RetryQueue
  alias Pleroma.Web.OStatus
  alias Pleroma.Web.Salmon
  alias Pleroma.Web.WebFinger
  alias Pleroma.Web.Websub

  require Logger

  @websub Application.get_env(:pleroma, :websub)
  @ostatus Application.get_env(:pleroma, :ostatus)

  def init do
    # 1 minute
    Process.sleep(1000 * 60)
    refresh_subscriptions()
  end

  # Client API

  def incoming_doc(doc) do
    PleromaJobQueue.enqueue(:federator_incoming, __MODULE__, [:incoming_doc, doc])
  end

  def incoming_ap_doc(params) do
    PleromaJobQueue.enqueue(:federator_incoming, __MODULE__, [:incoming_ap_doc, params])
  end

  def publish(activity, priority \\ 1) do
    PleromaJobQueue.enqueue(:federator_outgoing, __MODULE__, [:publish, activity], priority)
  end

  def publish_single_websub(websub) do
    PleromaJobQueue.enqueue(:federator_outgoing, __MODULE__, [:publish_single_websub, websub])
  end

  def verify_websub(websub) do
    PleromaJobQueue.enqueue(:federator_outgoing, __MODULE__, [:verify_websub, websub])
  end

  def request_subscription(sub) do
    PleromaJobQueue.enqueue(:federator_outgoing, __MODULE__, [:request_subscription, sub])
  end

  def refresh_subscriptions do
    PleromaJobQueue.enqueue(:federator_outgoing, __MODULE__, [:refresh_subscriptions])
  end

  def publish_single_salmon(params) do
    PleromaJobQueue.enqueue(:federator_outgoing, __MODULE__, [:publish_single_salmon, params])
  end

  # Job Worker Callbacks

  def perform(:refresh_subscriptions) do
    Logger.debug("Federator running refresh subscriptions")
    Websub.refresh_subscriptions()

    spawn(fn ->
      # 6 hours
      Process.sleep(1000 * 60 * 60 * 6)
      refresh_subscriptions()
    end)
  end

  def perform(:request_subscription, websub) do
    Logger.debug("Refreshing #{websub.topic}")

    with {:ok, websub} <- Websub.request_subscription(websub) do
      Logger.debug("Successfully refreshed #{websub.topic}")
    else
      _e -> Logger.debug("Couldn't refresh #{websub.topic}")
    end
  end

  def perform(:publish, activity) do
    Logger.debug(fn -> "Running publish for #{activity.data["id"]}" end)

    with actor when not is_nil(actor) <- User.get_cached_by_ap_id(activity.data["actor"]) do
      {:ok, actor} = WebFinger.ensure_keys_present(actor)

      if Visibility.is_public?(activity) do
        if OStatus.is_representable?(activity) do
          Logger.info(fn -> "Sending #{activity.data["id"]} out via WebSub" end)
          Websub.publish(Pleroma.Web.OStatus.feed_path(actor), actor, activity)

          Logger.info(fn -> "Sending #{activity.data["id"]} out via Salmon" end)
          Pleroma.Web.Salmon.publish(actor, activity)
        end
      end

      Publisher.publish(actor, activity)
    end
  end

  def perform(:verify_websub, websub) do
    Logger.debug(fn ->
      "Running WebSub verification for #{websub.id} (#{websub.topic}, #{websub.callback})"
    end)

    @websub.verify(websub)
  end

  def perform(:incoming_doc, doc) do
    Logger.info("Got document, trying to parse")
    @ostatus.handle_incoming(doc)
  end

  def perform(:incoming_ap_doc, params) do
    Logger.info("Handling incoming AP activity")

    params = Utils.normalize_params(params)

    # NOTE: we use the actor ID to do the containment, this is fine because an
    # actor shouldn't be acting on objects outside their own AP server.
    with {:ok, _user} <- ap_enabled_actor(params["actor"]),
         nil <- Activity.normalize(params["id"]),
         :ok <- Containment.contain_origin_from_id(params["actor"], params),
         {:ok, activity} <- Transmogrifier.handle_incoming(params) do
      {:ok, activity}
    else
      %Activity{} ->
        Logger.info("Already had #{params["id"]}")
        :error

      _e ->
        # Just drop those for now
        Logger.info("Unhandled activity")
        Logger.info(Poison.encode!(params, pretty: 2))
        :error
    end
  end

  def perform(:publish_single_salmon, params) do
    Salmon.send_to_user(params)
  end

  def perform(
        :publish_single_websub,
        %{xml: _xml, topic: _topic, callback: _callback, secret: _secret} = params
      ) do
    case Websub.publish_one(params) do
      {:ok, _} ->
        :ok

      {:error, _} ->
        RetryQueue.enqueue(params, Websub)
    end
  end

  def perform(type, _) do
    Logger.debug(fn -> "Unknown task: #{type}" end)
    {:error, "Don't know what to do with this"}
  end

  def ap_enabled_actor(id) do
    user = User.get_cached_by_ap_id(id)

    if User.ap_enabled?(user) do
      {:ok, user}
    else
      ActivityPub.make_user_from_ap_id(id)
    end
  end
end
