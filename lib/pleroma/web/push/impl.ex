# Pleroma: A lightweight social networking server
# Copyright © 2017-2020 Pleroma Authors <https://pleroma.social/>
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

  defdelegate mastodon_notification_type(activity), to: Activity

  @types ["Create", "Follow", "Announce", "Like", "Move"]

  @doc "Performs sending notifications for user subscriptions"
  @spec perform(Notification.t()) :: list(any) | :error
  def perform(
        %{
          activity: %{data: %{"type" => activity_type}} = activity,
          user: %User{id: user_id}
        } = notification
      )
      when activity_type in @types do
    actor = User.get_cached_by_ap_id(notification.activity.data["actor"])

    mastodon_type = mastodon_notification_type(notification.activity)
    gcm_api_key = Application.get_env(:web_push_encryption, :gcm_api_key)
    avatar_url = User.avatar_url(actor)
    object = Object.normalize(activity)
    user = User.get_cached_by_id(user_id)
    direct_conversation_id = Activity.direct_conversation_id(activity, user)

    for subscription <- fetch_subscriptions(user_id),
        Subscription.enabled?(subscription, mastodon_type) do
      %{
        access_token: subscription.token.token,
        notification_id: notification.id,
        notification_type: mastodon_type,
        icon: avatar_url,
        preferred_locale: "en",
        pleroma: %{
          activity_id: notification.activity.id,
          direct_conversation_id: direct_conversation_id
        }
      }
      |> Map.merge(build_content(notification, actor, object, mastodon_type))
      |> Jason.encode!()
      |> push_message(build_sub(subscription), gcm_api_key, subscription)
    end
  end

  def perform(_) do
    Logger.warn("Unknown notification type")
    :error
  end

  @doc "Push message to web"
  def push_message(body, sub, api_key, subscription) do
    case WebPushEncryption.send_web_push(body, sub, api_key) do
      {:ok, %{status_code: code}} when 400 <= code and code < 500 ->
        Logger.debug("Removing subscription record")
        Repo.delete!(subscription)
        :ok

      {:ok, %{status_code: code}} when 200 <= code and code < 300 ->
        :ok

      {:ok, %{status_code: code}} ->
        Logger.error("Web Push Notification failed with code: #{code}")
        :error

      _ ->
        Logger.error("Web Push Notification failed with unknown error")
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

  def build_content(notification, actor, object, mastodon_type \\ nil)

  def build_content(
        %{
          activity: %{data: %{"directMessage" => true}},
          user: %{notification_settings: %{privacy_option: true}}
        },
        actor,
        _object,
        _mastodon_type
      ) do
    %{title: "New Direct Message", body: "@#{actor.nickname}"}
  end

  def build_content(notification, actor, object, mastodon_type) do
    mastodon_type = mastodon_type || mastodon_notification_type(notification.activity)

    %{
      title: format_title(notification, mastodon_type),
      body: format_body(notification, actor, object, mastodon_type)
    }
  end

  def format_body(activity, actor, object, mastodon_type \\ nil)

  def format_body(
        %{activity: %{data: %{"type" => "Create"}}},
        actor,
        %{data: %{"content" => content}},
        _mastodon_type
      ) do
    "@#{actor.nickname}: #{Utils.scrub_html_and_truncate(content, 80)}"
  end

  def format_body(
        %{activity: %{data: %{"type" => "Announce"}}},
        actor,
        %{data: %{"content" => content}},
        _mastodon_type
      ) do
    "@#{actor.nickname} repeated: #{Utils.scrub_html_and_truncate(content, 80)}"
  end

  def format_body(
        %{activity: %{data: %{"type" => type}}} = notification,
        actor,
        _object,
        mastodon_type
      )
      when type in ["Follow", "Like"] do
    mastodon_type = mastodon_type || mastodon_notification_type(notification.activity)

    case mastodon_type do
      "follow" -> "@#{actor.nickname} has followed you"
      "follow_request" -> "@#{actor.nickname} has requested to follow you"
      "favourite" -> "@#{actor.nickname} has favorited your post"
    end
  end

  def format_title(activity, mastodon_type \\ nil)

  def format_title(%{activity: %{data: %{"directMessage" => true}}}, _mastodon_type) do
    "New Direct Message"
  end

  def format_title(%{activity: activity}, mastodon_type) do
    mastodon_type = mastodon_type || mastodon_notification_type(activity)

    case mastodon_type do
      "mention" -> "New Mention"
      "follow" -> "New Follower"
      "follow_request" -> "New Follow Request"
      "reblog" -> "New Repeat"
      "favourite" -> "New Favorite"
      type -> "New #{String.capitalize(type || "event")}"
    end
  end
end
