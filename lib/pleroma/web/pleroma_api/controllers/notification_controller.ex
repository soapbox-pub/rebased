# Pleroma: A lightweight social networking server
# Copyright © 2017-2022 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.PleromaAPI.NotificationController do
  use Pleroma.Web, :controller

  alias Pleroma.Notification

  plug(Pleroma.Web.ApiSpec.CastAndValidate)

  plug(
    Pleroma.Web.Plugs.OAuthScopesPlug,
    %{scopes: ["write:notifications"]} when action == :mark_as_read
  )

  defdelegate open_api_operation(action), to: Pleroma.Web.ApiSpec.PleromaNotificationOperation

  def mark_as_read(%{assigns: %{user: user}, body_params: %{id: notification_id}} = conn, _) do
    with {:ok, notification} <- Notification.read_one(user, notification_id) do
      render(conn, "show.json", notification: notification, for: user)
    else
      {:error, message} ->
        conn
        |> put_status(:bad_request)
        |> json(%{"error" => message})
    end
  end

  def mark_as_read(%{assigns: %{user: user}, body_params: %{max_id: max_id}} = conn, _) do
    notifications =
      user
      |> Notification.set_read_up_to(max_id)
      |> Enum.take(80)

    render(conn, "index.json", notifications: notifications, for: user)
  end
end
