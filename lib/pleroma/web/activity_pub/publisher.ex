# Pleroma: A lightweight social networking server
# Copyright © 2017-2022 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.ActivityPub.Publisher do
  alias Pleroma.Activity
  alias Pleroma.Config
  alias Pleroma.Delivery
  alias Pleroma.HTTP
  alias Pleroma.Instances
  alias Pleroma.Object
  alias Pleroma.Repo
  alias Pleroma.User
  alias Pleroma.Web.ActivityPub.Relay
  alias Pleroma.Web.ActivityPub.Transmogrifier
  alias Pleroma.Workers.PublisherWorker

  require Pleroma.Constants

  import Pleroma.Web.ActivityPub.Visibility

  require Logger

  @moduledoc """
  ActivityPub outgoing federation module.
  """

  @doc """
  Enqueue publishing a single activity.
  """
  @spec enqueue_one(map(), Keyword.t()) :: {:ok, %Oban.Job{}}
  def enqueue_one(%{} = params, worker_args \\ []) do
    PublisherWorker.enqueue(
      "publish_one",
      %{"params" => params},
      worker_args
    )
  end

  @doc """
  Gathers a set of remote users given an IR envelope.
  """
  def remote_users(%User{id: user_id}, %{data: %{"to" => to} = data}) do
    cc = Map.get(data, "cc", [])

    bcc =
      data
      |> Map.get("bcc", [])
      |> Enum.reduce([], fn ap_id, bcc ->
        case Pleroma.List.get_by_ap_id(ap_id) do
          %Pleroma.List{user_id: ^user_id} = list ->
            {:ok, following} = Pleroma.List.get_following(list)
            bcc ++ Enum.map(following, & &1.ap_id)

          _ ->
            bcc
        end
      end)

    [to, cc, bcc]
    |> Enum.concat()
    |> Enum.map(&User.get_cached_by_ap_id/1)
    |> Enum.filter(fn user -> user && !user.local end)
  end

  @doc """
  Determine if an activity can be represented by running it through Transmogrifier.
  """
  def representable?(%Activity{} = activity) do
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
  * `activity_id`: the internal activity id
  * `cc`: the cc recipients relevant to this inbox (optional)
  """
  def publish_one(%{inbox: inbox, activity_id: activity_id} = params) do
    activity = Activity.get_by_id_with_user_actor(activity_id)
    actor = activity.user_actor

    ap_id = activity.data["id"]
    Logger.debug("Federating #{ap_id} to #{inbox}")
    uri = %{path: path} = URI.parse(inbox)

    {:ok, data} = Transmogrifier.prepare_outgoing(activity.data)

    cc = Map.get(params, :cc)

    json =
      data
      |> Map.put("cc", cc)
      |> Jason.encode!()

    digest = "SHA-256=" <> (:crypto.hash(:sha256, json) |> Base.encode64())

    date = Pleroma.Signature.signed_date()

    signature =
      Pleroma.Signature.sign(actor, %{
        "(request-target)": "post #{path}",
        host: signature_host(uri),
        "content-length": byte_size(json),
        digest: digest,
        date: date
      })

    with {:ok, %{status: code}} = result when code in 200..299 <-
           HTTP.post(
             inbox,
             json,
             [
               {"Content-Type", "application/activity+json"},
               {"Date", date},
               {"signature", signature},
               {"digest", digest}
             ]
           ) do
      if not Map.has_key?(params, :unreachable_since) || params[:unreachable_since] do
        Instances.set_reachable(inbox)
      end

      result
    else
      {_post_result, %{status: code} = response} = e ->
        unless params[:unreachable_since], do: Instances.set_unreachable(inbox)
        Logger.metadata(activity: activity_id, inbox: inbox, status: code)
        Logger.error("Publisher failed to inbox #{inbox} with status #{code}")

        case response do
          %{status: 400} -> {:cancel, :bad_request}
          %{status: 403} -> {:cancel, :forbidden}
          %{status: 404} -> {:cancel, :not_found}
          %{status: 410} -> {:cancel, :not_found}
          _ -> {:error, e}
        end

      {:error, {:already_started, _}} ->
        Logger.debug("Publisher snoozing worker job due worker :already_started race condition")
        connection_pool_snooze()

      {:error, :pool_full} ->
        Logger.debug("Publisher snoozing worker job due to full connection pool")
        connection_pool_snooze()

      e ->
        unless params[:unreachable_since], do: Instances.set_unreachable(inbox)
        Logger.metadata(activity: activity_id, inbox: inbox)
        Logger.error("Publisher failed to inbox #{inbox} #{inspect(e)}")
        {:error, e}
    end
  end

  defp connection_pool_snooze, do: {:snooze, 3}

  defp signature_host(%URI{port: port, scheme: scheme, host: host}) do
    if port == URI.default_port(scheme) do
      host
    else
      "#{host}:#{port}"
    end
  end

  def should_federate?(nil, _), do: false
  def should_federate?(_, true), do: true

  def should_federate?(inbox, _) do
    %{host: host} = URI.parse(inbox)

    quarantined_instances =
      Config.get([:instance, :quarantined_instances], [])
      |> Pleroma.Web.ActivityPub.MRF.instance_list_from_tuples()
      |> Pleroma.Web.ActivityPub.MRF.subdomains_regex()

    !Pleroma.Web.ActivityPub.MRF.subdomain_match?(quarantined_instances, host)
  end

  @spec recipients(User.t(), Activity.t()) :: [[User.t()]]
  defp recipients(actor, activity) do
    followers =
      if actor.follower_address in activity.recipients do
        User.get_external_followers(actor)
      else
        []
      end

    fetchers =
      with %Activity{data: %{"type" => "Delete"}} <- activity,
           %Object{id: object_id} <- Object.normalize(activity, fetch: false),
           fetchers <- User.get_delivered_users_by_object_id(object_id),
           _ <- Delivery.delete_all_by_object_id(object_id) do
        fetchers
      else
        _ ->
          []
      end

    mentioned = remote_users(actor, activity)
    non_mentioned = (followers ++ fetchers) -- mentioned

    [mentioned, non_mentioned]
  end

  defp get_cc_ap_ids(ap_id, recipients) do
    host = Map.get(URI.parse(ap_id), :host)

    recipients
    |> Enum.filter(fn %User{ap_id: ap_id} -> Map.get(URI.parse(ap_id), :host) == host end)
    |> Enum.map(& &1.ap_id)
  end

  defp maybe_use_sharedinbox(%User{shared_inbox: nil, inbox: inbox}), do: inbox
  defp maybe_use_sharedinbox(%User{shared_inbox: shared_inbox}), do: shared_inbox

  @doc """
  Determine a user inbox to use based on heuristics.  These heuristics
  are based on an approximation of the ``sharedInbox`` rules in the
  [ActivityPub specification][ap-sharedinbox].

  Please do not edit this function (or its children) without reading
  the spec, as editing the code is likely to introduce some breakage
  without some familiarity.

     [ap-sharedinbox]: https://www.w3.org/TR/activitypub/#shared-inbox-delivery
  """
  def determine_inbox(
        %Activity{data: activity_data},
        %User{inbox: inbox} = user
      ) do
    to = activity_data["to"] || []
    cc = activity_data["cc"] || []
    type = activity_data["type"]

    cond do
      type == "Delete" ->
        maybe_use_sharedinbox(user)

      Pleroma.Constants.as_public() in to || Pleroma.Constants.as_public() in cc ->
        maybe_use_sharedinbox(user)

      length(to) + length(cc) > 1 ->
        maybe_use_sharedinbox(user)

      true ->
        inbox
    end
  end

  @doc """
  Publishes an activity with BCC to all relevant peers.
  """

  def publish(%User{} = actor, %{data: %{"bcc" => bcc}} = activity)
      when is_list(bcc) and bcc != [] do
    public = public?(activity)

    [priority_recipients, recipients] = recipients(actor, activity)

    inboxes =
      [priority_recipients, recipients]
      |> Enum.map(fn recipients ->
        recipients
        |> Enum.map(fn %User{} = user ->
          determine_inbox(activity, user)
        end)
        |> Enum.uniq()
        |> Enum.filter(fn inbox -> should_federate?(inbox, public) end)
        |> Instances.filter_reachable()
      end)

    Repo.checkout(fn ->
      Enum.each(inboxes, fn inboxes ->
        Enum.each(inboxes, fn {inbox, unreachable_since} ->
          %User{ap_id: ap_id} = Enum.find(recipients, fn actor -> actor.inbox == inbox end)

          # Get all the recipients on the same host and add them to cc. Otherwise, a remote
          # instance would only accept a first message for the first recipient and ignore the rest.
          cc = get_cc_ap_ids(ap_id, recipients)

          __MODULE__.enqueue_one(%{
            inbox: inbox,
            cc: cc,
            activity_id: activity.id,
            unreachable_since: unreachable_since
          })
        end)
      end)
    end)
  end

  # Publishes an activity to all relevant peers.
  def publish(%User{} = actor, %Activity{} = activity) do
    public = public?(activity)

    if public && Config.get([:instance, :allow_relay]) do
      Logger.debug(fn -> "Relaying #{activity.data["id"]} out" end)
      Relay.publish(activity)
    end

    [priority_inboxes, inboxes] =
      recipients(actor, activity)
      |> Enum.map(fn recipients ->
        recipients
        |> Enum.map(fn %User{} = user ->
          determine_inbox(activity, user)
        end)
        |> Enum.uniq()
        |> Enum.filter(fn inbox -> should_federate?(inbox, public) end)
      end)

    inboxes = inboxes -- priority_inboxes

    [{priority_inboxes, 0}, {inboxes, 1}]
    |> Enum.each(fn {inboxes, priority} ->
      inboxes
      |> Instances.filter_reachable()
      |> Enum.each(fn {inbox, unreachable_since} ->
        __MODULE__.enqueue_one(
          %{
            inbox: inbox,
            activity_id: activity.id,
            unreachable_since: unreachable_since
          },
          priority: priority
        )
      end)
    end)

    :ok
  end

  def gather_webfinger_links(%User{} = user) do
    [
      %{"rel" => "self", "type" => "application/activity+json", "href" => user.ap_id},
      %{
        "rel" => "self",
        "type" => "application/ld+json; profile=\"https://www.w3.org/ns/activitystreams\"",
        "href" => user.ap_id
      },
      %{
        "rel" => "http://ostatus.org/schema/1.0/subscribe",
        "template" => "#{Pleroma.Web.Endpoint.url()}/ostatus_subscribe?acct={uri}"
      }
    ]
  end

  def gather_nodeinfo_protocol_names, do: ["activitypub"]
end
