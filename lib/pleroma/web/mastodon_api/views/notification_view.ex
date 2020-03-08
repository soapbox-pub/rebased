# Pleroma: A lightweight social networking server
# Copyright © 2017-2020 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.MastodonAPI.NotificationView do
  use Pleroma.Web, :view

  alias Pleroma.Activity
  alias Pleroma.Notification
  alias Pleroma.User
  alias Pleroma.Web.CommonAPI
  alias Pleroma.Web.MastodonAPI.AccountView
  alias Pleroma.Web.MastodonAPI.NotificationView
  alias Pleroma.Web.MastodonAPI.StatusView

  def render("index.json", %{notifications: notifications, for: user}) do
    safe_render_many(notifications, NotificationView, "show.json", %{for: user})
  end

  def render("show.json", %{
        notification: %Notification{activity: activity} = notification,
        for: user
      }) do
    actor = User.get_cached_by_ap_id(activity.data["actor"])
    parent_activity = Activity.get_create_by_object_ap_id(activity.data["object"])
    mastodon_type = Activity.mastodon_notification_type(activity)

    with %{id: _} = account <- AccountView.render("show.json", %{user: actor, for: user}) do
      response = %{
        id: to_string(notification.id),
        type: mastodon_type,
        created_at: CommonAPI.Utils.to_masto_date(notification.inserted_at),
        account: account,
        pleroma: %{
          is_seen: notification.seen
        }
      }

      case mastodon_type do
        "mention" ->
          put_status(response, activity, user)

        "favourite" ->
          put_status(response, parent_activity, user)

        "reblog" ->
          put_status(response, parent_activity, user)

        "move" ->
          put_target(response, activity, user)

        "follow" ->
          response

        "pleroma:emoji_reaction" ->
          put_status(response, parent_activity, user) |> put_emoji(activity)

        _ ->
          nil
      end
    else
      _ -> nil
    end
  end

  defp put_emoji(response, activity) do
    response
    |> Map.put(:emoji, activity.data["content"])
  end

  defp put_status(response, activity, user) do
    Map.put(response, :status, StatusView.render("show.json", %{activity: activity, for: user}))
  end

  defp put_target(response, activity, user) do
    target = User.get_cached_by_ap_id(activity.data["target"])
    Map.put(response, :target, AccountView.render("show.json", %{user: target, for: user}))
  end
end
