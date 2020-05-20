# Pleroma: A lightweight social networking server
# Copyright © 2017-2020 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.PleromaAPI.PleromaAPIController do
  use Pleroma.Web, :controller

  alias Pleroma.Notification
  alias Pleroma.Plugs.OAuthScopesPlug
  alias Pleroma.Web.MastodonAPI.NotificationView

  plug(Pleroma.Web.ApiSpec.CastAndValidate)

  plug(
    OAuthScopesPlug,
    %{scopes: ["write:notifications"]} when action == :mark_notifications_as_read
  )

  defdelegate open_api_operation(action), to: Pleroma.Web.ApiSpec.PleromaOperation

  def mark_notifications_as_read(%{assigns: %{user: user}} = conn, %{id: notification_id}) do
    with {:ok, notification} <- Notification.read_one(user, notification_id) do
      conn
      |> put_view(NotificationView)
      |> render("show.json", %{notification: notification, for: user})
    else
      {:error, message} ->
        conn
        |> put_status(:bad_request)
        |> json(%{"error" => message})
    end
  end

  def mark_notifications_as_read(%{assigns: %{user: user}} = conn, %{max_id: max_id}) do
    with notifications <- Notification.set_read_up_to(user, max_id) do
      notifications = Enum.take(notifications, 80)

      conn
      |> put_view(NotificationView)
      |> render("index.json",
        notifications: notifications,
        for: user
      )
    end
  end
end
