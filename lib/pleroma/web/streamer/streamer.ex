# Pleroma: A lightweight social networking server
# Copyright © 2017-2020 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.Streamer do
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
  alias Pleroma.Web.StreamerView

  @mix_env Mix.env()
  @registry Pleroma.Web.StreamerRegistry

  def registry, do: @registry

  @public_streams ["public", "public:local", "public:media", "public:local:media"]
  @user_streams ["user", "user:notification", "direct"]

  @doc "Expands and authorizes a stream, and registers the process for streaming."
  @spec get_topic_and_add_socket(stream :: String.t(), User.t() | nil, Map.t() | nil) ::
          {:ok, topic :: String.t()} | {:error, :bad_topic} | {:error, :unauthorized}
  def get_topic_and_add_socket(stream, user, params \\ %{}) do
    case get_topic(stream, user, params) do
      {:ok, topic} -> add_socket(topic, user)
      error -> error
    end
  end

  @doc "Expand and authorizes a stream"
  @spec get_topic(stream :: String.t(), User.t() | nil, Map.t()) ::
          {:ok, topic :: String.t()} | {:error, :bad_topic}
  def get_topic(stream, user, params \\ %{})

  # Allow all public steams.
  def get_topic(stream, _, _) when stream in @public_streams do
    {:ok, stream}
  end

  # Allow all hashtags streams.
  def get_topic("hashtag", _, %{"tag" => tag}) do
    {:ok, "hashtag:" <> tag}
  end

  # Expand user streams.
  def get_topic(stream, %User{} = user, _) when stream in @user_streams do
    {:ok, stream <> ":" <> to_string(user.id)}
  end

  def get_topic(stream, _, _) when stream in @user_streams do
    {:error, :unauthorized}
  end

  # List streams.
  def get_topic("list", %User{} = user, %{"list" => id}) do
    if Pleroma.List.get(id, user) do
      {:ok, "list:" <> to_string(id)}
    else
      {:error, :bad_topic}
    end
  end

  def get_topic("list", _, _) do
    {:error, :unauthorized}
  end

  def get_topic(_, _, _) do
    {:error, :bad_topic}
  end

  @doc "Registers the process for streaming. Use `get_topic/3` to get the full authorized topic."
  def add_socket(topic, user) do
    if should_env_send?() do
      auth? = if user, do: true
      Registry.register(@registry, topic, auth?)
    end

    {:ok, topic}
  end

  def remove_socket(topic) do
    if should_env_send?(), do: Registry.unregister(@registry, topic)
  end

  def stream(topics, item) when is_list(topics) do
    if should_env_send?() do
      Enum.each(topics, fn t ->
        spawn(fn -> do_stream(t, item) end)
      end)
    end

    :ok
  end

  def stream(topic, items) when is_list(items) do
    if should_env_send?() do
      Enum.each(items, fn i ->
        spawn(fn -> do_stream(topic, i) end)
      end)

      :ok
    end
  end

  def stream(topic, item) do
    if should_env_send?() do
      spawn(fn -> do_stream(topic, item) end)
    end

    :ok
  end

  def filtered_by_user?(%User{} = user, %Activity{} = item) do
    %{block: blocked_ap_ids, mute: muted_ap_ids, reblog_mute: reblog_muted_ap_ids} =
      User.outgoing_relationships_ap_ids(user, [:block, :mute, :reblog_mute])

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
      false
    else
      _ -> true
    end
  end

  def filtered_by_user?(%User{} = user, %Notification{activity: activity}) do
    filtered_by_user?(user, activity)
  end

  defp do_stream("direct", item) do
    recipient_topics =
      User.get_recipients_from_activity(item)
      |> Enum.map(fn %{id: id} -> "direct:#{id}" end)

    Enum.each(recipient_topics, fn user_topic ->
      Logger.debug("Trying to push direct message to #{user_topic}\n\n")
      push_to_socket(user_topic, item)
    end)
  end

  defp do_stream("participation", participation) do
    user_topic = "direct:#{participation.user_id}"
    Logger.debug("Trying to push a conversation participation to #{user_topic}\n\n")

    push_to_socket(user_topic, participation)
  end

  defp do_stream("list", item) do
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
      push_to_socket(list_topic, item)
    end)
  end

  defp do_stream(topic, %Notification{} = item)
       when topic in ["user", "user:notification"] do
    Registry.dispatch(@registry, "#{topic}:#{item.user_id}", fn list ->
      Enum.each(list, fn {pid, _auth} ->
        send(pid, {:render_with_user, StreamerView, "notification.json", item})
      end)
    end)
  end

  defp do_stream("user", item) do
    Logger.debug("Trying to push to users")

    recipient_topics =
      User.get_recipients_from_activity(item)
      |> Enum.map(fn %{id: id} -> "user:#{id}" end)

    Enum.each(recipient_topics, fn topic ->
      push_to_socket(topic, item)
    end)
  end

  defp do_stream(topic, item) do
    Logger.debug("Trying to push to #{topic}")
    Logger.debug("Pushing item to #{topic}")
    push_to_socket(topic, item)
  end

  defp push_to_socket(topic, %Participation{} = participation) do
    rendered = StreamerView.render("conversation.json", participation)

    Registry.dispatch(@registry, topic, fn list ->
      Enum.each(list, fn {pid, _} ->
        send(pid, {:text, rendered})
      end)
    end)
  end

  defp push_to_socket(topic, %Activity{
         data: %{"type" => "Delete", "deleted_activity_id" => deleted_activity_id}
       }) do
    rendered = Jason.encode!(%{event: "delete", payload: to_string(deleted_activity_id)})

    Registry.dispatch(@registry, topic, fn list ->
      Enum.each(list, fn {pid, _} ->
        send(pid, {:text, rendered})
      end)
    end)
  end

  defp push_to_socket(_topic, %Activity{data: %{"type" => "Delete"}}), do: :noop

  defp push_to_socket(topic, item) do
    anon_render = StreamerView.render("update.json", item)

    Registry.dispatch(@registry, topic, fn list ->
      Enum.each(list, fn {pid, auth?} ->
        if auth? do
          send(pid, {:render_with_user, StreamerView, "update.json", item})
        else
          send(pid, {:text, anon_render})
        end
      end)
    end)
  end

  defp thread_containment(_activity, %User{skip_thread_containment: true}), do: true

  defp thread_containment(activity, user) do
    if Config.get([:instance, :skip_thread_containment]) do
      true
    else
      ActivityPub.contain_activity(activity, user)
    end
  end

  # In test environement, only return true if the registry is started.
  # In benchmark environment, returns false.
  # In any other environment, always returns true.
  cond do
    @mix_env == :test ->
      def should_env_send? do
        case Process.whereis(@registry) do
          nil ->
            false

          pid ->
            Process.alive?(pid)
        end
      end

    @mix_env == :benchmark ->
      def should_env_send?, do: false

    true ->
      def should_env_send?, do: true
  end
end
