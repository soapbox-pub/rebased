# Pleroma: A lightweight social networking server
# Copyright © 2017-2020 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.Streamer.Worker do
  use GenServer

  require Logger

  alias Pleroma.Activity
  alias Pleroma.Config
  alias Pleroma.Conversation.Participation
  alias Pleroma.Notification
  alias Pleroma.Object
  alias Pleroma.User
  alias Pleroma.Web.ActivityPub.ActivityPub
  alias Pleroma.Web.ActivityPub.Visibility
  alias Pleroma.Web.CommonAPI
  alias Pleroma.Web.Streamer.State
  alias Pleroma.Web.Streamer.StreamerSocket
  alias Pleroma.Web.StreamerView

  def start_link(_) do
    GenServer.start_link(__MODULE__, %{}, [])
  end

  def init(init_arg) do
    {:ok, init_arg}
  end

  def stream(pid, topics, items) do
    GenServer.call(pid, {:stream, topics, items})
  end

  def handle_call({:stream, topics, item}, _from, state) when is_list(topics) do
    Enum.each(topics, fn t ->
      do_stream(%{topic: t, item: item})
    end)

    {:reply, state, state}
  end

  def handle_call({:stream, topic, items}, _from, state) when is_list(items) do
    Enum.each(items, fn i ->
      do_stream(%{topic: topic, item: i})
    end)

    {:reply, state, state}
  end

  def handle_call({:stream, topic, item}, _from, state) do
    do_stream(%{topic: topic, item: item})

    {:reply, state, state}
  end

  defp do_stream(%{topic: "direct", item: item}) do
    recipient_topics =
      User.get_recipients_from_activity(item)
      |> Enum.map(fn %{id: id} -> "direct:#{id}" end)

    Enum.each(recipient_topics, fn user_topic ->
      Logger.debug("Trying to push direct message to #{user_topic}\n\n")
      push_to_socket(State.get_sockets(), user_topic, item)
    end)
  end

  defp do_stream(%{topic: "participation", item: participation}) do
    user_topic = "direct:#{participation.user_id}"
    Logger.debug("Trying to push a conversation participation to #{user_topic}\n\n")

    push_to_socket(State.get_sockets(), user_topic, participation)
  end

  defp do_stream(%{topic: "list", item: item}) do
    # filter the recipient list if the activity is not public, see #270.
    recipient_lists =
      case Visibility.is_public?(item) do
        true ->
          Pleroma.List.get_lists_from_activity(item)

        _ ->
          Pleroma.List.get_lists_from_activity(item)
          |> Enum.filter(fn list ->
            owner = User.get_cached_by_id(list.user_id)

            Visibility.visible_for_user?(item, owner)
          end)
      end

    recipient_topics =
      recipient_lists
      |> Enum.map(fn %{id: id} -> "list:#{id}" end)

    Enum.each(recipient_topics, fn list_topic ->
      Logger.debug("Trying to push message to #{list_topic}\n\n")
      push_to_socket(State.get_sockets(), list_topic, item)
    end)
  end

  defp do_stream(%{topic: topic, item: %Notification{} = item})
       when topic in ["user", "user:notification"] do
    State.get_sockets()
    |> Map.get("#{topic}:#{item.user_id}", [])
    |> Enum.each(fn %StreamerSocket{transport_pid: transport_pid, user: socket_user} ->
      with %User{} = user <- User.get_cached_by_ap_id(socket_user.ap_id),
           true <- should_send?(user, item) do
        send(transport_pid, {:text, StreamerView.render("notification.json", socket_user, item)})
      end
    end)
  end

  defp do_stream(%{topic: "user", item: item}) do
    Logger.debug("Trying to push to users")

    recipient_topics =
      User.get_recipients_from_activity(item)
      |> Enum.map(fn %{id: id} -> "user:#{id}" end)

    Enum.each(recipient_topics, fn topic ->
      push_to_socket(State.get_sockets(), topic, item)
    end)
  end

  defp do_stream(%{topic: topic, item: item}) do
    Logger.debug("Trying to push to #{topic}")
    Logger.debug("Pushing item to #{topic}")
    push_to_socket(State.get_sockets(), topic, item)
  end

  defp should_send?(%User{} = user, %Activity{} = item) do
    %{block: blocked_ap_ids, mute: muted_ap_ids, reblog_mute: reblog_muted_ap_ids} =
      User.outgoing_relations_ap_ids(user, [:block, :mute, :reblog_mute])

    recipient_blocks = MapSet.new(blocked_ap_ids ++ muted_ap_ids)
    recipients = MapSet.new(item.recipients)
    domain_blocks = Pleroma.Web.ActivityPub.MRF.subdomains_regex(user.domain_blocks)

    with parent <- Object.normalize(item) || item,
         true <-
           Enum.all?([blocked_ap_ids, muted_ap_ids], &(item.actor not in &1)),
         true <- item.data["type"] != "Announce" || item.actor not in reblog_muted_ap_ids,
         true <- Enum.all?([blocked_ap_ids, muted_ap_ids], &(parent.data["actor"] not in &1)),
         true <- MapSet.disjoint?(recipients, recipient_blocks),
         %{host: item_host} <- URI.parse(item.actor),
         %{host: parent_host} <- URI.parse(parent.data["actor"]),
         false <- Pleroma.Web.ActivityPub.MRF.subdomain_match?(domain_blocks, item_host),
         false <- Pleroma.Web.ActivityPub.MRF.subdomain_match?(domain_blocks, parent_host),
         true <- thread_containment(item, user),
         false <- CommonAPI.thread_muted?(user, item) do
      true
    else
      _ -> false
    end
  end

  defp should_send?(%User{} = user, %Notification{activity: activity}) do
    should_send?(user, activity)
  end

  def push_to_socket(topics, topic, %Activity{data: %{"type" => "Announce"}} = item) do
    Enum.each(topics[topic] || [], fn %StreamerSocket{
                                        transport_pid: transport_pid,
                                        user: socket_user
                                      } ->
      # Get the current user so we have up-to-date blocks etc.
      if socket_user do
        user = User.get_cached_by_ap_id(socket_user.ap_id)

        if should_send?(user, item) do
          send(transport_pid, {:text, StreamerView.render("update.json", item, user)})
        end
      else
        send(transport_pid, {:text, StreamerView.render("update.json", item)})
      end
    end)
  end

  def push_to_socket(topics, topic, %Participation{} = participation) do
    Enum.each(topics[topic] || [], fn %StreamerSocket{transport_pid: transport_pid} ->
      send(transport_pid, {:text, StreamerView.render("conversation.json", participation)})
    end)
  end

  def push_to_socket(topics, topic, %Activity{
        data: %{"type" => "Delete", "deleted_activity_id" => deleted_activity_id}
      }) do
    Enum.each(topics[topic] || [], fn %StreamerSocket{transport_pid: transport_pid} ->
      send(
        transport_pid,
        {:text, %{event: "delete", payload: to_string(deleted_activity_id)} |> Jason.encode!()}
      )
    end)
  end

  def push_to_socket(_topics, _topic, %Activity{data: %{"type" => "Delete"}}), do: :noop

  def push_to_socket(topics, topic, item) do
    Enum.each(topics[topic] || [], fn %StreamerSocket{
                                        transport_pid: transport_pid,
                                        user: socket_user
                                      } ->
      # Get the current user so we have up-to-date blocks etc.
      if socket_user do
        user = User.get_cached_by_ap_id(socket_user.ap_id)

        if should_send?(user, item) do
          send(transport_pid, {:text, StreamerView.render("update.json", item, user)})
        end
      else
        send(transport_pid, {:text, StreamerView.render("update.json", item)})
      end
    end)
  end

  @spec thread_containment(Activity.t(), User.t()) :: boolean()
  defp thread_containment(_activity, %User{skip_thread_containment: true}), do: true

  defp thread_containment(activity, user) do
    if Config.get([:instance, :skip_thread_containment]) do
      true
    else
      ActivityPub.contain_activity(activity, user)
    end
  end
end
