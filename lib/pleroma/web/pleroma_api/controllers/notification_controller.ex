# Pleroma: A lightweight social networking server
# Copyright © 2017-2022 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.PleromaAPI.NotificationController do
  use Pleroma.Web, :controller

  alias Pleroma.Notification

  plug(Pleroma.Web.ApiSpec.CastAndValidate, replace_params: false)

  plug(
    Pleroma.Web.Plugs.OAuthScopesPlug,
    %{scopes: ["write:notifications"]} when action == :mark_as_read
  )

  defdelegate open_api_operation(action), to: Pleroma.Web.ApiSpec.PleromaNotificationOperation

  def mark_as_read(
        %{
          assigns: %{user: user},
          private: %{open_api_spex: %{body_params: %{id: notification_id}}}
        } = conn,
        _
      ) do
    with {:ok, _} <- Notification.read_one(user, notification_id) do
      conn
      |> json("ok")
    else
      {:error, message} ->
        conn
        |> put_status(:bad_request)
        |> json(%{"error" => message})
    end
  end

  def mark_as_read(
        %{assigns: %{user: user}, private: %{open_api_spex: %{body_params: %{max_id: max_id}}}} =
          conn,
        _
      ) do
    with {:ok, _} <- Notification.set_read_up_to(user, max_id) do
      conn
      |> json("ok")
    else
      {:error, message} ->
        conn
        |> put_status(:bad_request)
        |> json(%{"error" => message})
    end
  end
end
