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
    actor = User.get_cached_by_ap_id(notification.activity.data["actor"])

    gcm_api_key = Application.get_env(:web_push_encryption, :gcm_api_key)
    avatar_url = User.avatar_url(actor)
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
      |> Map.merge(build_content(notification, actor, object))
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
        _actor,
        _object
      ) do
    %{body: format_title(notification)}
  end

  def build_content(notification, actor, object) do
    %{
      title: format_title(notification),
      body: format_body(notification, actor, object)
    }
  end

  def format_body(_activity, actor, %{data: %{"type" => "ChatMessage"} = data}) do
    case data["content"] do
      nil -> "@#{actor.nickname}: (Attachment)"
      content -> "@#{actor.nickname}: #{Utils.scrub_html_and_truncate(content, 80)}"
    end
  end

  def format_body(
        %{activity: %{data: %{"type" => "Create"}}},
        actor,
        %{data: %{"content" => content}}
      ) do
    "@#{actor.nickname}: #{Utils.scrub_html_and_truncate(content, 80)}"
  end

  def format_body(
        %{activity: %{data: %{"type" => "Announce"}}},
        actor,
        %{data: %{"content" => content}}
      ) do
    "@#{actor.nickname} repeated: #{Utils.scrub_html_and_truncate(content, 80)}"
  end

  def format_body(
        %{activity: %{data: %{"type" => "EmojiReact", "content" => content}}},
        actor,
        _object
      ) do
    "@#{actor.nickname} reacted with #{content}"
  end

  def format_body(
        %{activity: %{data: %{"type" => type}}} = notification,
        actor,
        _object
      )
      when type in ["Follow", "Like"] do
    case notification.type do
      "follow" -> "@#{actor.nickname} has followed you"
      "follow_request" -> "@#{actor.nickname} has requested to follow you"
      "favourite" -> "@#{actor.nickname} has favorited your post"
    end
  end

  def format_body(
        %{activity: %{data: %{"type" => "Update"}}},
        actor,
        _object
      ) do
    "@#{actor.nickname} edited a status"
  end

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
      type -> "New #{String.capitalize(type || "event")}"
    end
  end
end
