# Pleroma: A lightweight social networking server
# Copyright © 2017-2021 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.MastodonAPI.AuthController do
  use Pleroma.Web, :controller

  import Pleroma.Web.ControllerHelper, only: [json_response: 3]

  alias Pleroma.Helpers.AuthHelper
  alias Pleroma.Helpers.UriHelper
  alias Pleroma.User
  alias Pleroma.Web.OAuth.App
  alias Pleroma.Web.OAuth.Authorization
  alias Pleroma.Web.OAuth.Token
  alias Pleroma.Web.OAuth.Token.Strategy.Revoke, as: RevokeToken
  alias Pleroma.Web.TwitterAPI.TwitterAPI

  action_fallback(Pleroma.Web.MastodonAPI.FallbackController)

  plug(Pleroma.Web.Plugs.RateLimiter, [name: :password_reset] when action == :password_reset)

  @local_mastodon_name "Mastodon-Local"

  @doc "GET /web/login"
  # Local Mastodon FE login callback action
  def login(conn, %{"code" => auth_token} = params) do
    with {:ok, app} <- local_mastofe_app(),
         {:ok, auth} <- Authorization.get_by_token(app, auth_token),
         {:ok, oauth_token} <- Token.exchange_token(app, auth) do
      redirect_to =
        conn
        |> local_mastodon_post_login_path()
        |> UriHelper.modify_uri_params(%{"access_token" => oauth_token.token})

      conn
      |> AuthHelper.put_session_token(oauth_token.token)
      |> redirect(to: redirect_to)
    else
      _ -> redirect_to_oauth_form(conn, params)
    end
  end

  def login(conn, params) do
    with %{assigns: %{user: %User{}, token: %Token{app_id: app_id}}} <- conn,
         {:ok, %{id: ^app_id}} <- local_mastofe_app() do
      redirect(conn, to: local_mastodon_post_login_path(conn))
    else
      _ -> redirect_to_oauth_form(conn, params)
    end
  end

  defp redirect_to_oauth_form(conn, _params) do
    with {:ok, app} <- local_mastofe_app() do
      path =
        o_auth_path(conn, :authorize,
          response_type: "code",
          client_id: app.client_id,
          redirect_uri: ".",
          scope: Enum.join(app.scopes, " ")
        )

      redirect(conn, to: path)
    end
  end

  @doc "DELETE /auth/sign_out"
  def logout(conn, _) do
    conn =
      with %{assigns: %{token: %Token{} = oauth_token}} <- conn,
           session_token = AuthHelper.get_session_token(conn),
           {:ok, %Token{token: ^session_token}} <- RevokeToken.revoke(oauth_token) do
        AuthHelper.delete_session_token(conn)
      else
        _ -> conn
      end

    redirect(conn, to: "/")
  end

  @doc "POST /auth/password"
  def password_reset(conn, params) do
    nickname_or_email = params["email"] || params["nickname"]

    TwitterAPI.password_reset(nickname_or_email)

    json_response(conn, :no_content, "")
  end

  defp local_mastodon_post_login_path(conn) do
    case get_session(conn, :return_to) do
      nil ->
        masto_fe_path(conn, :index, ["getting-started"])

      return_to ->
        delete_session(conn, :return_to)
        return_to
    end
  end

  @spec local_mastofe_app() :: {:ok, App.t()} | {:error, Ecto.Changeset.t()}
  def local_mastofe_app do
    App.get_or_make(
      %{client_name: @local_mastodon_name, redirect_uris: "."},
      ["read", "write", "follow", "push", "admin"]
    )
  end
end
