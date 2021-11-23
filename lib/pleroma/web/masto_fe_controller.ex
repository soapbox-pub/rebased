# Pleroma: A lightweight social networking server
# Copyright © 2017-2021 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.MastoFEController do
  use Pleroma.Web, :controller

  alias Pleroma.User
  alias Pleroma.Web.MastodonAPI.AuthController
  alias Pleroma.Web.OAuth.Token
  alias Pleroma.Web.Plugs.OAuthScopesPlug

  plug(OAuthScopesPlug, %{scopes: ["write:accounts"]} when action == :put_settings)

  # Note: :index action handles attempt of unauthenticated access to private instance with redirect
  plug(:skip_public_check when action == :index)

  plug(
    OAuthScopesPlug,
    %{scopes: ["read"], fallback: :proceed_unauthenticated}
    when action == :index
  )

  plug(:skip_auth when action == :manifest)

  @doc "GET /web/*path"
  def index(conn, _params) do
    with %{assigns: %{user: %User{} = user, token: %Token{app_id: token_app_id} = token}} <- conn,
         {:ok, %{id: ^token_app_id}} <- AuthController.local_mastofe_app() do
      conn
      |> put_layout(false)
      |> render("index.html",
        token: token.token,
        user: user,
        custom_emojis: Pleroma.Emoji.get_all()
      )
    else
      _ ->
        conn
        |> put_session(:return_to, conn.request_path)
        |> redirect(to: "/web/login")
    end
  end

  @doc "GET /web/manifest.json"
  def manifest(conn, _params) do
    render(conn, "manifest.json")
  end

  @doc "PUT /api/web/settings: Backend-obscure settings blob for MastoFE, don't parse/reuse elsewhere"
  def put_settings(%{assigns: %{user: user}} = conn, %{"data" => settings} = _params) do
    with {:ok, _} <- User.mastodon_settings_update(user, settings) do
      json(conn, %{})
    else
      e ->
        conn
        |> put_status(:internal_server_error)
        |> json(%{error: inspect(e)})
    end
  end
end
