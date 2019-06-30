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
  alias Pleroma.Web.Federator.Publisher
  alias Pleroma.Web.Federator.RetryQueue
  alias Pleroma.Web.OStatus
  alias Pleroma.Web.Websub

  require Logger

  def init do
    # 1 minute
    Process.sleep(1000 * 60)
    refresh_subscriptions()
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
    PleromaJobQueue.enqueue(:federator_incoming, __MODULE__, [:incoming_doc, doc])
  end

  def incoming_ap_doc(params) do
    PleromaJobQueue.enqueue(:federator_incoming, __MODULE__, [:incoming_ap_doc, params])
  end

  def publish(activity, priority \\ 1) do
    PleromaJobQueue.enqueue(:federator_outgoing, __MODULE__, [:publish, activity], priority)
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

    with %User{} = actor <- User.get_cached_by_ap_id(activity.data["actor"]),
         {:ok, actor} <- User.ensure_keys_present(actor) do
      Publisher.publish(actor, activity)
    end
  end

  def perform(:verify_websub, websub) do
    Logger.debug(fn ->
      "Running WebSub verification for #{websub.id} (#{websub.topic}, #{websub.callback})"
    end)

    Websub.verify(websub)
  end

  def perform(:incoming_doc, doc) do
    Logger.info("Got document, trying to parse")
    OStatus.handle_incoming(doc)
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
        Logger.info(Jason.encode!(params, pretty: true))
        :error
    end
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
