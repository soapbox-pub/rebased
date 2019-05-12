# Pleroma: A lightweight social networking server
# Copyright © 2017-2019 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.ActivityPub.Publisher do
  alias Pleroma.Activity
  alias Pleroma.Config
  alias Pleroma.Instances
  alias Pleroma.User
  alias Pleroma.Web.ActivityPub.Relay
  alias Pleroma.Web.ActivityPub.Transmogrifier

  import Pleroma.Web.ActivityPub.Visibility

  @behaviour Pleroma.Web.Federator.Publisher

  require Logger

  @httpoison Application.get_env(:pleroma, :httpoison)

  @moduledoc """
  ActivityPub outgoing federation module.
  """

  @doc """
  Determine if an activity can be represented by running it through Transmogrifier.
  """
  def is_representable?(%Activity{} = activity) do
    with {:ok, _data} <- Transmogrifier.prepare_outgoing(activity.data) do
      true
    else
      _e ->
        false
    end
  end

  @doc """
  Publish a single message to a peer.  Takes a struct with the following
  parameters set:

  * `inbox`: the inbox to publish to
  * `json`: the JSON message body representing the ActivityPub message
  * `actor`: the actor which is signing the message
  * `id`: the ActivityStreams URI of the message
  """
  def publish_one(%{inbox: inbox, json: json, actor: %User{} = actor, id: id} = params) do
    Logger.info("Federating #{id} to #{inbox}")
    host = URI.parse(inbox).host

    digest = "SHA-256=" <> (:crypto.hash(:sha256, json) |> Base.encode64())

    date =
      NaiveDateTime.utc_now()
      |> Timex.format!("{WDshort}, {0D} {Mshort} {YYYY} {h24}:{m}:{s} GMT")

    signature =
      Pleroma.Web.HTTPSignatures.sign(actor, %{
        host: host,
        "content-length": byte_size(json),
        digest: digest,
        date: date
      })

    with {:ok, %{status: code}} when code in 200..299 <-
           result =
             @httpoison.post(
               inbox,
               json,
               [
                 {"Content-Type", "application/activity+json"},
                 {"Date", date},
                 {"signature", signature},
                 {"digest", digest}
               ]
             ) do
      if !Map.has_key?(params, :unreachable_since) || params[:unreachable_since],
        do: Instances.set_reachable(inbox)

      result
    else
      {_post_result, response} ->
        unless params[:unreachable_since], do: Instances.set_unreachable(inbox)
        {:error, response}
    end
  end

  defp should_federate?(inbox, public) do
    if public do
      true
    else
      inbox_info = URI.parse(inbox)
      !Enum.member?(Pleroma.Config.get([:instance, :quarantined_instances], []), inbox_info.host)
    end
  end

  @doc """
  Publishes an activity to all relevant peers.
  """
  def publish(%User{} = actor, %Activity{} = activity) do
    remote_followers =
      if actor.follower_address in activity.recipients do
        {:ok, followers} = User.get_followers(actor)
        followers |> Enum.filter(&(!&1.local))
      else
        []
      end

    public = is_public?(activity)

    if public && Config.get([:instance, :allow_relay]) do
      Logger.info(fn -> "Relaying #{activity.data["id"]} out" end)
      Relay.publish(activity)
    end

    {:ok, data} = Transmogrifier.prepare_outgoing(activity.data)
    json = Jason.encode!(data)

    (Pleroma.Web.Salmon.remote_users(activity) ++ remote_followers)
    |> Enum.filter(fn user -> User.ap_enabled?(user) end)
    |> Enum.map(fn %{info: %{source_data: data}} ->
      (is_map(data["endpoints"]) && Map.get(data["endpoints"], "sharedInbox")) || data["inbox"]
    end)
    |> Enum.uniq()
    |> Enum.filter(fn inbox -> should_federate?(inbox, public) end)
    |> Instances.filter_reachable()
    |> Enum.each(fn {inbox, unreachable_since} ->
      Pleroma.Web.Federator.Publisher.enqueue_one(
        __MODULE__,
        %{
          inbox: inbox,
          json: json,
          actor: actor,
          id: activity.data["id"],
          unreachable_since: unreachable_since
        }
      )
    end)
  end
end
