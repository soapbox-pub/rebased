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
  alias Pleroma.Workers.PublisherWorker
  alias Pleroma.Workers.ReceiverWorker

  require Logger

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

  def incoming_ap_doc(params) do
    ReceiverWorker.enqueue("incoming_ap_doc", %{"params" => params})
  end

  def publish(%{id: "pleroma:fakeid"} = activity) do
    perform(:publish, activity)
  end

  def publish(activity) do
    PublisherWorker.enqueue("publish", %{"activity_id" => activity.id})
  end

  # Job Worker Callbacks

  @spec perform(atom(), module(), any()) :: {:ok, any()} | {:error, any()}
  def perform(:publish_one, module, params) do
    apply(module, :publish_one, [params])
  end

  def perform(:publish, activity) do
    Logger.debug(fn -> "Running publish for #{activity.data["id"]}" end)

    with %User{} = actor <- User.get_cached_by_ap_id(activity.data["actor"]),
         {:ok, actor} <- User.ensure_keys_present(actor) do
      Publisher.publish(actor, activity)
    end
  end

  def perform(:incoming_ap_doc, params) do
    Logger.debug("Handling incoming AP activity")

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
        Logger.debug("Already had #{params["id"]}")
        :error

      _e ->
        # Just drop those for now
        Logger.debug("Unhandled activity")
        Logger.debug(Jason.encode!(params, pretty: true))
        :error
    end
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
