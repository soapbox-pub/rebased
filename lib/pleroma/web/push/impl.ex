# Pleroma: A lightweight social networking server
# Copyright © 2017-2022 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.Push.Impl do
  @moduledoc "The module represents implementation push web notification"

  alias Pleroma.Activity
  alias Pleroma.Notification
  alias Pleroma.Object
  alias Pleroma.Repo
  alias Pleroma.User
  alias Pleroma.Web.Metadata.Utils
  alias Pleroma.Web.Push.Subscription

  require Logger
  import Ecto.Query

  @types ["Create", "Follow", "Announce", "Like", "Move", "EmojiReact", "Update"]

  @doc "Performs sending notifications for user subscriptions"
  @spec perform(Notification.t()) :: list(any) | :error | {:error, :unknown_type}
  def perform(
        %{
          activity: %{data: %{"type" => activity_type}} = activity,
          user: %User{id: user_id}
        } = notification
      )
      when activity_type in @types do
    user = User.get_cached_by_ap_id(notification.activity.data["actor"])

    gcm_api_key = Application.get_env(:web_push_encryption, :gcm_api_key)
    avatar_url = User.avatar_url(user)
    object = Object.normalize(activity, fetch: false)
    user = User.get_cached_by_id(user_id)
    direct_conversation_id = Activity.direct_conversation_id(activity, user)

    for subscription <- fetch_subscriptions(user_id),
        Subscription.enabled?(subscription, notification.type) do
      %{
        access_token: subscription.token.token,
        notification_id: notification.id,
        notification_type: notification.type,
        icon: avatar_url,
        preferred_locale: "en",
        pleroma: %{
          activity_id: notification.activity.id,
          direct_conversation_id: direct_conversation_id
        }
      }
      |> Map.merge(build_content(notification, user, object))
      |> Jason.encode!()
      |> push_message(build_sub(subscription), gcm_api_key, subscription)
    end
    |> (&{:ok, &1}).()
  end

  def perform(_) do
    Logger.warning("Unknown notification type")
    {:error, :unknown_type}
  end

  @doc "Push message to web"
  def push_message(body, sub, api_key, subscription) do
    try do
      case WebPushEncryption.send_web_push(body, sub, api_key) do
        {:ok, %{status: code}} when code in 400..499 ->
          Logger.debug("Removing subscription record")
          Repo.delete!(subscription)
          :ok

        {:ok, %{status: code}} when code in 200..299 ->
          :ok

        {:ok, %{status: code}} ->
          Logger.error("Web Push Notification failed with code: #{code}")
          :error

        error ->
          Logger.error("Web Push Notification failed with #{inspect(error)}")
          :error
      end
    rescue
      error ->
        Logger.error("Web Push Notification failed with #{inspect(error)}")
        :error
    end
  end

  @doc "Gets user subscriptions"
  def fetch_subscriptions(user_id) do
    Subscription
    |> where(user_id: ^user_id)
    |> preload(:token)
    |> Repo.all()
  end

  def build_sub(subscription) do
    %{
      keys: %{
        p256dh: subscription.key_p256dh,
        auth: subscription.key_auth
      },
      endpoint: subscription.endpoint
    }
  end

  def build_content(
        %{
          user: %{notification_settings: %{hide_notification_contents: true}}
        } = notification,
        _user,
        _object
      ) do
    %{body: format_title(notification)}
  end

  def build_content(notification, user, object) do
    %{
      title: format_title(notification),
      body: format_body(notification, user, object)
    }
  end

  @spec format_body(Notification.t(), User.t(), Object.t()) :: String.t()
  def format_body(_notification, user, %{data: %{"type" => "ChatMessage"} = object}) do
    case object["content"] do
      nil -> "@#{user.nickname}: (Attachment)"
      content -> "@#{user.nickname}: #{Utils.scrub_html_and_truncate(content, 80)}"
    end
  end

  def format_body(
        %{type: "poll"} = _notification,
        _user,
        %{data: %{"content" => content} = data} = _object
      ) do
    options = Map.get(data, "anyOf") || Map.get(data, "oneOf")

    content_text = content <> "\n"

    options_text =
      Enum.map(options, fn x -> "○ #{x["name"]}" end)
      |> Enum.join("\n")

    [content_text, options_text]
    |> Enum.join("\n")
    |> Utils.scrub_html_and_truncate(80)
  end

  def format_body(
        %{activity: %{data: %{"type" => "Create"}}},
        user,
        %{data: %{"content" => content}}
      ) do
    "@#{user.nickname}: #{Utils.scrub_html_and_truncate(content, 80)}"
  end

  def format_body(
        %{activity: %{data: %{"type" => "Announce"}}},
        user,
        %{data: %{"content" => content}}
      ) do
    "@#{user.nickname} repeated: #{Utils.scrub_html_and_truncate(content, 80)}"
  end

  def format_body(
        %{activity: %{data: %{"type" => "EmojiReact", "content" => content}}},
        user,
        _object
      ) do
    "@#{user.nickname} reacted with #{content}"
  end

  def format_body(
        %{activity: %{data: %{"type" => type}}} = notification,
        user,
        _object
      )
      when type in ["Follow", "Like"] do
    case notification.type do
      "follow" -> "@#{user.nickname} has followed you"
      "follow_request" -> "@#{user.nickname} has requested to follow you"
      "favourite" -> "@#{user.nickname} has favorited your post"
    end
  end

  def format_body(
        %{activity: %{data: %{"type" => "Update"}}},
        user,
        _object
      ) do
    "@#{user.nickname} edited a status"
  end

  @spec format_title(Notification.t()) :: String.t()
  def format_title(%{activity: %{data: %{"directMessage" => true}}}) do
    "New Direct Message"
  end

  def format_title(%{type: type}) do
    case type do
      "mention" -> "New Mention"
      "status" -> "New Status"
      "follow" -> "New Follower"
      "follow_request" -> "New Follow Request"
      "reblog" -> "New Repeat"
      "favourite" -> "New Favorite"
      "update" -> "New Update"
      "pleroma:chat_mention" -> "New Chat Message"
      "pleroma:emoji_reaction" -> "New Reaction"
      "poll" -> "Poll Results"
      type -> "New #{String.capitalize(type || "event")}"
    end
  end
end
