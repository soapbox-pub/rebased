# Pleroma: A lightweight social networking server
# Copyright © 2017-2019 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Workers.Receiver do
  alias Pleroma.Activity
  alias Pleroma.Object.Containment
  alias Pleroma.User
  alias Pleroma.Web.ActivityPub.ActivityPub
  alias Pleroma.Web.ActivityPub.Transmogrifier
  alias Pleroma.Web.ActivityPub.Utils
  alias Pleroma.Web.OStatus

  require Logger

  # Note: `max_attempts` is intended to be overridden in `new/1` call
  use Oban.Worker,
    queue: "federator_incoming",
    max_attempts: Pleroma.Config.get([:workers, :retries, :compile_time_default])

  @impl Oban.Worker
  def perform(%{"op" => "incoming_doc", "body" => doc}) do
    Logger.info("Got incoming document, trying to parse")
    OStatus.handle_incoming(doc)
  end

  def perform(%{"op" => "incoming_ap_doc", "params" => params}) do
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

  defp ap_enabled_actor(id) do
    user = User.get_cached_by_ap_id(id)

    if User.ap_enabled?(user) do
      {:ok, user}
    else
      ActivityPub.make_user_from_ap_id(id)
    end
  end
end
