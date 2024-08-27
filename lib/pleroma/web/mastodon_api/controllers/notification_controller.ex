# Pleroma: A lightweight social networking server
# Copyright © 2017-2022 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.MastodonAPI.NotificationController do
  use Pleroma.Web, :controller

  import Pleroma.Web.ControllerHelper, only: [add_link_headers: 2]

  alias Pleroma.Notification
  alias Pleroma.Web.MastodonAPI.MastodonAPI
  alias Pleroma.Web.Plugs.OAuthScopesPlug

  @oauth_read_actions [:show, :index]

  plug(Pleroma.Web.ApiSpec.CastAndValidate, replace_params: false)

  plug(
    OAuthScopesPlug,
    %{scopes: ["read:notifications"]} when action in @oauth_read_actions
  )

  plug(OAuthScopesPlug, %{scopes: ["write:notifications"]} when action not in @oauth_read_actions)

  defdelegate open_api_operation(action), to: Pleroma.Web.ApiSpec.NotificationOperation

  @default_notification_types ~w{
      mention
      follow
      follow_request
      reblog
      favourite
      move
      pleroma:emoji_reaction
      poll
      update
      status
      bite
    }

  # GET /api/v1/notifications
  def index(%{private: %{open_api_spex: %{params: %{account_id: account_id} = params}}} = conn, _) do
    case Pleroma.User.get_cached_by_id(account_id) do
      %{ap_id: account_ap_id} ->
        params =
          params
          |> Map.delete(:account_id)
          |> Map.put(:account_ap_id, account_ap_id)

        do_get_notifications(conn, params)

      _ ->
        conn
        |> put_status(:not_found)
        |> json(%{"error" => "Account is not found"})
    end
  end

  def index(%{private: %{open_api_spex: %{params: params}}} = conn, _) do
    do_get_notifications(conn, params)
  end

  defp do_get_notifications(%{assigns: %{user: user}} = conn, params) do
    params =
      Map.new(params, fn {k, v} -> {to_string(k), v} end)
      |> Map.put_new("types", Map.get(params, :include_types, @default_notification_types))

    notifications = MastodonAPI.get_notifications(user, params)

    conn
    |> add_link_headers(notifications)
    |> render("index.json",
      notifications: notifications,
      for: user
    )
  end

  # GET /api/v1/notifications/:id
  def show(%{assigns: %{user: user}, private: %{open_api_spex: %{params: %{id: id}}}} = conn, _) do
    with {:ok, notification} <- Notification.get(user, id) do
      render(conn, "show.json", notification: notification, for: user)
    else
      {:error, reason} ->
        conn
        |> put_status(:forbidden)
        |> json(%{"error" => reason})
    end
  end

  # POST /api/v1/notifications/clear
  def clear(%{assigns: %{user: user}} = conn, _params) do
    Notification.clear(user)
    json(conn, %{})
  end

  # POST /api/v1/notifications/:id/dismiss

  def dismiss(%{private: %{open_api_spex: %{params: %{id: id}}}} = conn, _) do
    do_dismiss(conn, id)
  end

  # POST /api/v1/notifications/dismiss (deprecated)
  def dismiss_via_body(
        %{private: %{open_api_spex: %{body_params: %{id: id}}}} = conn,
        _
      ) do
    do_dismiss(conn, id)
  end

  defp do_dismiss(%{assigns: %{user: user}} = conn, notification_id) do
    with {:ok, _notif} <- Notification.dismiss(user, notification_id) do
      json(conn, %{})
    else
      {:error, reason} ->
        conn
        |> put_status(:forbidden)
        |> json(%{"error" => reason})
    end
  end

  # DELETE /api/v1/notifications/destroy_multiple
  def destroy_multiple(
        %{assigns: %{user: user}, private: %{open_api_spex: %{params: %{ids: ids}}}} = conn,
        _
      ) do
    Notification.destroy_multiple(user, ids)
    json(conn, %{})
  end
end
