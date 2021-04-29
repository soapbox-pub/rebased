# Pleroma: A lightweight social networking server
# Copyright © 2017-2021 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.TwitterAPI.Controller do
  use Pleroma.Web, :controller

  alias Pleroma.Notification
  alias Pleroma.User
  alias Pleroma.Web.OAuth.Token
  alias Pleroma.Web.Plugs.EnsurePublicOrAuthenticatedPlug
  alias Pleroma.Web.Plugs.OAuthScopesPlug
  alias Pleroma.Web.TwitterAPI.TokenView

  require Logger

  plug(
    OAuthScopesPlug,
    %{scopes: ["write:notifications"]} when action == :mark_notifications_as_read
  )

  plug(
    :skip_plug,
    [OAuthScopesPlug, EnsurePublicOrAuthenticatedPlug] when action == :confirm_email
  )

  plug(:skip_plug, OAuthScopesPlug when action in [:oauth_tokens, :revoke_token])

  action_fallback(:errors)

  def confirm_email(conn, %{"user_id" => uid, "token" => token}) do
    with %User{} = user <- User.get_cached_by_id(uid),
         true <- user.local and !user.is_confirmed and user.confirmation_token == token,
         {:ok, _} <- User.confirm(user) do
      redirect(conn, to: "/")
    end
  end

  def oauth_tokens(%{assigns: %{user: user}} = conn, _params) do
    with oauth_tokens <- Token.get_user_tokens(user) do
      conn
      |> put_view(TokenView)
      |> render("index.json", %{tokens: oauth_tokens})
    end
  end

  def revoke_token(%{assigns: %{user: user}} = conn, %{"id" => id} = _params) do
    Token.delete_user_token(user, id)

    json_reply(conn, 201, "")
  end

  defp errors(conn, {:param_cast, _}) do
    conn
    |> put_status(400)
    |> json("Invalid parameters")
  end

  defp errors(conn, _) do
    conn
    |> put_status(500)
    |> json("Something went wrong")
  end

  defp json_reply(conn, status, json) do
    conn
    |> put_resp_content_type("application/json")
    |> send_resp(status, json)
  end

  def mark_notifications_as_read(
        %{assigns: %{user: user}} = conn,
        %{"latest_id" => latest_id} = params
      ) do
    Notification.set_read_up_to(user, latest_id)

    notifications = Notification.for_user(user, params)

    conn
    # XXX: This is a hack because pleroma-fe still uses that API.
    |> put_view(Pleroma.Web.MastodonAPI.NotificationView)
    |> render("index.json", %{notifications: notifications, for: user})
  end

  def mark_notifications_as_read(%{assigns: %{user: _user}} = conn, _) do
    bad_request_reply(conn, "You need to specify latest_id")
  end

  defp bad_request_reply(conn, error_message) do
    json = error_json(conn, error_message)
    json_reply(conn, 400, json)
  end

  defp error_json(conn, error_message) do
    %{"error" => error_message, "request" => conn.request_path} |> Jason.encode!()
  end
end
