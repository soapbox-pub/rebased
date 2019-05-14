# Pleroma: A lightweight social networking server
# Copyright © 2017-2019 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.Streamer do
  use GenServer
  require Logger
  alias Pleroma.Activity
  alias Pleroma.Conversation.Participation
  alias Pleroma.Notification
  alias Pleroma.Object
  alias Pleroma.User
  alias Pleroma.Web.ActivityPub.ActivityPub
  alias Pleroma.Web.ActivityPub.Visibility
  alias Pleroma.Web.MastodonAPI.NotificationView

  @keepalive_interval :timer.seconds(30)

  def start_link do
    GenServer.start_link(__MODULE__, %{}, name: __MODULE__)
  end

  def add_socket(topic, socket) do
    GenServer.cast(__MODULE__, %{action: :add, socket: socket, topic: topic})
  end

  def remove_socket(topic, socket) do
    GenServer.cast(__MODULE__, %{action: :remove, socket: socket, topic: topic})
  end

  def stream(topic, item) do
    GenServer.cast(__MODULE__, %{action: :stream, topic: topic, item: item})
  end

  def init(args) do
    spawn(fn ->
      # 30 seconds
      Process.sleep(@keepalive_interval)
      GenServer.cast(__MODULE__, %{action: :ping})
    end)

    {:ok, args}
  end

  def handle_cast(%{action: :ping}, topics) do
    Map.values(topics)
    |> List.flatten()
    |> Enum.each(fn socket ->
      Logger.debug("Sending keepalive ping")
      send(socket.transport_pid, {:text, ""})
    end)

    spawn(fn ->
      # 30 seconds
      Process.sleep(@keepalive_interval)
      GenServer.cast(__MODULE__, %{action: :ping})
    end)

    {:noreply, topics}
  end

  def handle_cast(%{action: :stream, topic: "direct", item: item}, topics) do
    recipient_topics =
      User.get_recipients_from_activity(item)
      |> Enum.map(fn %{id: id} -> "direct:#{id}" end)

    Enum.each(recipient_topics || [], fn user_topic ->
      Logger.debug("Trying to push direct message to #{user_topic}\n\n")
      push_to_socket(topics, user_topic, item)
    end)

    {:noreply, topics}
  end

  def handle_cast(%{action: :stream, topic: "participation", item: participation}, topics) do
    user_topic = "direct:#{participation.user_id}"
    Logger.debug("Trying to push a conversation participation to #{user_topic}\n\n")

    push_to_socket(topics, user_topic, participation)

    {:noreply, topics}
  end

  def handle_cast(%{action: :stream, topic: "list", item: item}, topics) do
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

    Enum.each(recipient_topics || [], fn list_topic ->
      Logger.debug("Trying to push message to #{list_topic}\n\n")
      push_to_socket(topics, list_topic, item)
    end)

    {:noreply, topics}
  end

  def handle_cast(%{action: :stream, topic: "user", item: %Notification{} = item}, topics) do
    topic = "user:#{item.user_id}"

    Enum.each(topics[topic] || [], fn socket ->
      json =
        %{
          event: "notification",
          payload:
            NotificationView.render("show.json", %{
              notification: item,
              for: socket.assigns["user"]
            })
            |> Jason.encode!()
        }
        |> Jason.encode!()

      send(socket.transport_pid, {:text, json})
    end)

    {:noreply, topics}
  end

  def handle_cast(%{action: :stream, topic: "user", item: item}, topics) do
    Logger.debug("Trying to push to users")

    recipient_topics =
      User.get_recipients_from_activity(item)
      |> Enum.map(fn %{id: id} -> "user:#{id}" end)

    Enum.each(recipient_topics, fn topic ->
      push_to_socket(topics, topic, item)
    end)

    {:noreply, topics}
  end

  def handle_cast(%{action: :stream, topic: topic, item: item}, topics) do
    Logger.debug("Trying to push to #{topic}")
    Logger.debug("Pushing item to #{topic}")
    push_to_socket(topics, topic, item)
    {:noreply, topics}
  end

  def handle_cast(%{action: :add, topic: topic, socket: socket}, sockets) do
    topic = internal_topic(topic, socket)
    sockets_for_topic = sockets[topic] || []
    sockets_for_topic = Enum.uniq([socket | sockets_for_topic])
    sockets = Map.put(sockets, topic, sockets_for_topic)
    Logger.debug("Got new conn for #{topic}")
    {:noreply, sockets}
  end

  def handle_cast(%{action: :remove, topic: topic, socket: socket}, sockets) do
    topic = internal_topic(topic, socket)
    sockets_for_topic = sockets[topic] || []
    sockets_for_topic = List.delete(sockets_for_topic, socket)
    sockets = Map.put(sockets, topic, sockets_for_topic)
    Logger.debug("Removed conn for #{topic}")
    {:noreply, sockets}
  end

  def handle_cast(m, state) do
    Logger.info("Unknown: #{inspect(m)}, #{inspect(state)}")
    {:noreply, state}
  end

  defp represent_update(%Activity{} = activity, %User{} = user) do
    %{
      event: "update",
      payload:
        Pleroma.Web.MastodonAPI.StatusView.render(
          "status.json",
          activity: activity,
          for: user
        )
        |> Jason.encode!()
    }
    |> Jason.encode!()
  end

  defp represent_update(%Activity{} = activity) do
    %{
      event: "update",
      payload:
        Pleroma.Web.MastodonAPI.StatusView.render(
          "status.json",
          activity: activity
        )
        |> Jason.encode!()
    }
    |> Jason.encode!()
  end

  def represent_conversation(%Participation{} = participation) do
    %{
      event: "conversation",
      payload:
        Pleroma.Web.MastodonAPI.ConversationView.render("participation.json", %{
          participation: participation,
          user: participation.user
        })
        |> Jason.encode!()
    }
    |> Jason.encode!()
  end

  def push_to_socket(topics, topic, %Activity{data: %{"type" => "Announce"}} = item) do
    Enum.each(topics[topic] || [], fn socket ->
      # Get the current user so we have up-to-date blocks etc.
      if socket.assigns[:user] do
        user = User.get_cached_by_ap_id(socket.assigns[:user].ap_id)
        blocks = user.info.blocks || []
        mutes = user.info.mutes || []
        reblog_mutes = user.info.muted_reblogs || []

        parent = Object.normalize(item)

        unless is_nil(parent) or item.actor in blocks or item.actor in mutes or
                 item.actor in reblog_mutes or not ActivityPub.contain_activity(item, user) or
                 parent.data["actor"] in blocks or parent.data["actor"] in mutes do
          send(socket.transport_pid, {:text, represent_update(item, user)})
        end
      else
        send(socket.transport_pid, {:text, represent_update(item)})
      end
    end)
  end

  def push_to_socket(topics, topic, %Participation{} = participation) do
    Enum.each(topics[topic] || [], fn socket ->
      send(socket.transport_pid, {:text, represent_conversation(participation)})
    end)
  end

  def push_to_socket(topics, topic, %Activity{
        data: %{"type" => "Delete", "deleted_activity_id" => deleted_activity_id}
      }) do
    Enum.each(topics[topic] || [], fn socket ->
      send(
        socket.transport_pid,
        {:text, %{event: "delete", payload: to_string(deleted_activity_id)} |> Jason.encode!()}
      )
    end)
  end

  def push_to_socket(_topics, _topic, %Activity{data: %{"type" => "Delete"}}), do: :noop

  def push_to_socket(topics, topic, item) do
    Enum.each(topics[topic] || [], fn socket ->
      # Get the current user so we have up-to-date blocks etc.
      if socket.assigns[:user] do
        user = User.get_cached_by_ap_id(socket.assigns[:user].ap_id)
        blocks = user.info.blocks || []
        mutes = user.info.mutes || []

        unless item.actor in blocks or item.actor in mutes or
                 not ActivityPub.contain_activity(item, user) do
          send(socket.transport_pid, {:text, represent_update(item, user)})
        end
      else
        send(socket.transport_pid, {:text, represent_update(item)})
      end
    end)
  end

  defp internal_topic(topic, socket) when topic in ~w[user direct] do
    "#{topic}:#{socket.assigns[:user].id}"
  end

  defp internal_topic(topic, _), do: topic
end
