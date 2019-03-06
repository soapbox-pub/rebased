# Pleroma: A lightweight social networking server
# Copyright © 2017-2019 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.Push.Impl do
  @moduledoc "The module represents implementation push web notification"

  alias Pleroma.Repo
  alias Pleroma.User
  alias Pleroma.Activity
  alias Pleroma.Object
  alias Pleroma.Web.Push.Subscription
  alias Pleroma.Web.Metadata.Utils
  alias Pleroma.Notification

  require Logger
  import Ecto.Query

  @types ["Create", "Follow", "Announce", "Like"]

  @doc "Performs sending notifications for user subscriptions"
  @spec perform_send(Notification.t()) :: list(any)
  def perform_send(%{activity: %{data: %{"type" => activity_type}}, user_id: user_id} = notif)
      when activity_type in @types do
    actor = User.get_cached_by_ap_id(notif.activity.data["actor"])

    type = Activity.mastodon_notification_type(notif.activity)
    gcm_api_key = Application.get_env(:web_push_encryption, :gcm_api_key)
    avatar_url = User.avatar_url(actor)

    for subscription <- fetch_subsriptions(user_id),
        get_in(subscription.data, ["alerts", type]) do
      %{
        title: format_title(notif),
        access_token: subscription.token.token,
        body: format_body(notif, actor),
        notification_id: notif.id,
        notification_type: type,
        icon: avatar_url,
        preferred_locale: "en"
      }
      |> Jason.encode!()
      |> push_message(build_sub(subscription), gcm_api_key, subscription)
    end
  end

  def perform_send(_) do
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
  def fetch_subsriptions(user_id) do
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

  def format_body(
        %{activity: %{data: %{"type" => "Create", "object" => %{"content" => content}}}},
        actor
      ) do
    "@#{actor.nickname}: #{Utils.scrub_html_and_truncate(content, 80)}"
  end

  def format_body(
        %{activity: %{data: %{"type" => "Announce", "object" => activity_id}}},
        actor
      ) do
    %Activity{data: %{"object" => %{"id" => object_id}}} = Activity.get_by_ap_id(activity_id)
    %Object{data: %{"content" => content}} = Object.get_by_ap_id(object_id)

    "@#{actor.nickname} repeated: #{Utils.scrub_html_and_truncate(content, 80)}"
  end

  def format_body(
        %{activity: %{data: %{"type" => type}}},
        actor
      )
      when type in ["Follow", "Like"] do
    case type do
      "Follow" -> "@#{actor.nickname} has followed you"
      "Like" -> "@#{actor.nickname} has favorited your post"
    end
  end

  def format_title(%{activity: %{data: %{"type" => type}}}) do
    case type do
      "Create" -> "New Mention"
      "Follow" -> "New Follower"
      "Announce" -> "New Repeat"
      "Like" -> "New Favorite"
    end
  end
end
