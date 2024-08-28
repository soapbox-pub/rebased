# Pleroma: A lightweight social networking server
# Copyright © 2017-2022 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.Federator do
  alias Pleroma.Activity
  alias Pleroma.Object.Containment
  alias Pleroma.User
  alias Pleroma.Web.ActivityPub.Publisher
  alias Pleroma.Web.ActivityPub.Transmogrifier
  alias Pleroma.Web.ActivityPub.Utils
  alias Pleroma.Workers.PublisherWorker
  alias Pleroma.Workers.ReceiverWorker

  require Logger

  @behaviour Pleroma.Web.Federator.Publishing

  @doc """
  Returns `true` if the distance to target object does not exceed max configured value.
  Serves to prevent fetching of very long threads, especially useful on smaller instances.
  Addresses [memory leaks on recursive replies fetching](https://git.pleroma.social/pleroma/pleroma/issues/161).
  Applies to fetching of both ancestor (reply-to) and child (reply) objects.
  """
  # credo:disable-for-previous-line Credo.Check.Readability.MaxLineLength
  def allowed_thread_distance?(distance) do
    max_distance = Pleroma.Config.get([:instance, :federation_incoming_replies_max_depth])

    if max_distance && max_distance >= 0 do
      # Default depth is 0 (an object has zero distance from itself in its thread)
      (distance || 0) <= max_distance
    else
      true
    end
  end

  # Client API
  def incoming_ap_doc(%{params: params, req_headers: req_headers}) do
    ReceiverWorker.new(
      %{
        "op" => "incoming_ap_doc",
        "req_headers" => req_headers,
        "params" => params,
        "timeout" => :timer.seconds(20)
      },
      priority: 2
    )
    |> Oban.insert()
  end

  def incoming_ap_doc(%{"type" => "Delete"} = params) do
    ReceiverWorker.new(%{"op" => "incoming_ap_doc", "params" => params},
      priority: 3,
      queue: :slow
    )
    |> Oban.insert()
  end

  def incoming_ap_doc(params) do
    ReceiverWorker.new(%{"op" => "incoming_ap_doc", "params" => params})
    |> Oban.insert()
  end

  @impl true
  def publish(%{id: "pleroma:fakeid"} = activity) do
    perform(:publish, activity)
  end

  @impl true
  def publish(%Pleroma.Activity{data: %{"type" => type}} = activity) do
    PublisherWorker.new(%{"op" => "publish", "activity_id" => activity.id},
      priority: publish_priority(type)
    )
    |> Oban.insert()
  end

  defp publish_priority("Delete"), do: 3
  defp publish_priority(_), do: 0

  # Job Worker Callbacks

  @spec perform(atom(), any()) :: {:ok, any()} | {:error, any()}
  def perform(:publish_one, params) do
    Publisher.prepare_one(params)
    |> Publisher.publish_one()
  end

  def perform(:publish, activity) do
    Logger.debug(fn -> "Running publish for #{activity.data["id"]}" end)

    %User{} = actor = User.get_cached_by_ap_id(activity.data["actor"])
    Publisher.publish(actor, activity)
  end

  def perform(:incoming_ap_doc, params) do
    Logger.debug("Handling incoming AP activity")

    actor =
      params
      |> Map.get("actor")
      |> Utils.get_ap_id()

    # NOTE: we use the actor ID to do the containment, this is fine because an
    # actor shouldn't be acting on objects outside their own AP server.
    with {_, {:ok, user}} <- {:actor, User.get_or_fetch_by_ap_id(actor)},
         {:user_active, true} <- {:user_active, match?(true, user.is_active)},
         nil <- Activity.normalize(params["id"]),
         {_, :ok} <-
           {:correct_origin?, Containment.contain_origin_from_id(actor, params)},
         {:ok, activity} <- Transmogrifier.handle_incoming(params) do
      {:ok, activity}
    else
      {:correct_origin?, _} ->
        Logger.debug("Origin containment failure for #{params["id"]}")
        {:error, :origin_containment_failed}

      %Activity{} ->
        Logger.debug("Already had #{params["id"]}")
        {:error, :already_present}

      {:actor, e} ->
        Logger.debug("Unhandled actor #{actor}, #{inspect(e)}")
        {:error, e}

      e ->
        # Just drop those for now
        Logger.debug(fn -> "Unhandled activity\n" <> Jason.encode!(params, pretty: true) end)
        {:error, e}
    end
  end
end
