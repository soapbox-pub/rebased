# Pleroma: A lightweight social networking server
# Copyright © 2017-2019 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.MastodonAPI.AppController do
  use Pleroma.Web, :controller

  alias Pleroma.Plugs.OAuthScopesPlug
  alias Pleroma.Repo
  alias Pleroma.Web.OAuth.App
  alias Pleroma.Web.OAuth.Scopes
  alias Pleroma.Web.OAuth.Token

  action_fallback(Pleroma.Web.MastodonAPI.FallbackController)

  plug(OAuthScopesPlug, %{scopes: ["read"]} when action == :verify_credentials)

  @local_mastodon_name "Mastodon-Local"

  @doc "POST /api/v1/apps"
  def create(conn, params) do
    scopes = Scopes.fetch_scopes(params, ["read"])

    app_attrs =
      params
      |> Map.drop(["scope", "scopes"])
      |> Map.put("scopes", scopes)

    with cs <- App.register_changeset(%App{}, app_attrs),
         false <- cs.changes[:client_name] == @local_mastodon_name,
         {:ok, app} <- Repo.insert(cs) do
      render(conn, "show.json", app: app)
    end
  end

  @doc "GET /api/v1/apps/verify_credentials"
  def verify_credentials(%{assigns: %{user: _user, token: token}} = conn, _) do
    with %Token{app: %App{} = app} <- Repo.preload(token, :app) do
      render(conn, "short.json", app: app)
    end
  end
end
