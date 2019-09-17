# Pleroma: A lightweight social networking server
# Copyright © 2017-2019 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.PleromaAPI.SubscriptionNotificationView do
  use Pleroma.Web, :view

  alias Pleroma.Activity
  alias Pleroma.Web.CommonAPI
  alias Pleroma.Web.MastodonAPI.AccountView
  alias Pleroma.Web.MastodonAPI.StatusView
  alias Pleroma.Web.PleromaAPI.SubscriptionNotificationView

  def render("index.json", %{notifications: notifications, for: user}) do
    safe_render_many(notifications, SubscriptionNotificationView, "show.json", %{for: user})
  end

  def render("show.json", %{
        subscription_notification: %{
          notification: %{activity: activity} = notification,
          actor: actor,
          parent_activity: parent_activity
        },
        for: user
      }) do
    mastodon_type = Activity.mastodon_notification_type(activity)

    response = %{
      id: to_string(notification.id),
      type: mastodon_type,
      created_at: CommonAPI.Utils.to_masto_date(notification.inserted_at),
      account: AccountView.render("account.json", %{user: actor, for: user})
    }

    case mastodon_type do
      "mention" ->
        response
        |> Map.merge(%{
          status: StatusView.render("status.json", %{activity: activity, for: user})
        })

      "favourite" ->
        response
        |> Map.merge(%{
          status: StatusView.render("status.json", %{activity: parent_activity, for: user})
        })

      "reblog" ->
        response
        |> Map.merge(%{
          status: StatusView.render("status.json", %{activity: parent_activity, for: user})
        })

      "follow" ->
        response

      _ ->
        nil
    end
  end
end
