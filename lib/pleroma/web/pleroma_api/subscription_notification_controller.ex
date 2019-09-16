# Pleroma: A lightweight social networking server
# Copyright © 2017-2019 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.PleromaAPI.SubscriptionNotificationController do
  use Pleroma.Web, :controller

  import Pleroma.Web.ControllerHelper, only: [add_link_headers: 2]

  alias Pleroma.SubscriptionNotification
  alias Pleroma.Web.PleromaAPI.PleromaAPI
  alias Pleroma.Web.PleromaAPI.SubscriptionNotificationView

  def list(%{assigns: %{user: user}} = conn, params) do
    notifications = PleromaAPI.get_subscription_notifications(user, params)

    conn
    |> add_link_headers(notifications)
    |> put_view(SubscriptionNotificationView)
    |> render("index.json", %{notifications: notifications, for: user})
  end

  def get(%{assigns: %{user: user}} = conn, %{"id" => id} = _params) do
    with {:ok, notification} <- SubscriptionNotification.get(user, id) do
      conn
      |> put_view(SubscriptionNotificationView)
      |> render("show.json", %{subscription_notification: notification, for: user})
    else
      {:error, reason} ->
        conn
        |> put_status(:forbidden)
        |> json(%{"error" => reason})
    end
  end

  def clear(%{assigns: %{user: user}} = conn, _params) do
    SubscriptionNotification.clear(user)
    json(conn, %{})
  end

  def dismiss(%{assigns: %{user: user}} = conn, %{"id" => id} = _params) do
    with {:ok, _notif} <- SubscriptionNotification.dismiss(user, id) do
      json(conn, %{})
    else
      {:error, reason} ->
        conn
        |> put_status(:forbidden)
        |> json(%{"error" => reason})
    end
  end

  def destroy_multiple(
        %{assigns: %{user: user}} = conn,
        %{"ids" => ids} = _params
      ) do
    SubscriptionNotification.destroy_multiple(user, ids)
    json(conn, %{})
  end
end
