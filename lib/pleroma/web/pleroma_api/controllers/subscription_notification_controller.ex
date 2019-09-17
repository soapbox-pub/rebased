# Pleroma: A lightweight social networking server
# Copyright © 2017-2019 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.PleromaAPI.SubscriptionNotificationController do
  use Pleroma.Web, :controller

  import Pleroma.Web.ControllerHelper, only: [add_link_headers: 2]

  alias Pleroma.Activity
  alias Pleroma.SubscriptionNotification
  alias Pleroma.User
  alias Pleroma.Web.PleromaAPI.PleromaAPI

  def index(%{assigns: %{user: user}} = conn, params) do
    notifications =
      user
      |> PleromaAPI.get_subscription_notifications(params)
      |> Enum.map(&build_notification_data/1)

    conn
    |> add_link_headers(notifications)
    |> render("index.json", %{notifications: notifications, for: user})
  end

  def show(%{assigns: %{user: user}} = conn, %{"id" => id} = _params) do
    with {:ok, notification} <- SubscriptionNotification.get(user, id) do
      render(conn, "show.json", %{
        subscription_notification: build_notification_data(notification),
        for: user
      })
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

  defp build_notification_data(%{activity: %{data: data}} = notification) do
    %{
      notification: notification,
      actor: User.get_cached_by_ap_id(data["actor"]),
      parent_activity: Activity.get_create_by_object_ap_id(data["object"])
    }
  end
end
