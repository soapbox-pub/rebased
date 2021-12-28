# Pleroma: A lightweight social networking server
# Copyright © 2017-2021 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.MastodonAPI.AppController do
  @moduledoc """
  Controller for supporting app-related actions.
  If authentication is an option, app tokens (user-unbound) must be supported.
  """

  use Pleroma.Web, :controller

  alias Pleroma.Maps
  alias Pleroma.Repo
  alias Pleroma.User
  alias Pleroma.Web.OAuth.App
  alias Pleroma.Web.OAuth.Scopes
  alias Pleroma.Web.OAuth.Token

  action_fallback(Pleroma.Web.MastodonAPI.FallbackController)

  plug(:skip_auth when action in [:create, :verify_credentials])

  plug(Pleroma.Web.ApiSpec.CastAndValidate)

  defdelegate open_api_operation(action), to: Pleroma.Web.ApiSpec.AppOperation

  @doc "POST /api/v1/apps"
  def create(%{body_params: params} = conn, _params) do
    scopes = Scopes.fetch_scopes(params, ["read"])
    user_id = get_user_id(conn)

    app_attrs =
      params
      |> Map.take([:client_name, :redirect_uris, :website])
      |> Map.put(:scopes, scopes)
      |> Maps.put_if_present(:user_id, user_id)

    with cs <- App.register_changeset(%App{}, app_attrs),
         {:ok, app} <- Repo.insert(cs) do
      render(conn, "show.json", app: app)
    end
  end

  defp get_user_id(%{assigns: %{user: %User{id: user_id}}}), do: user_id
  defp get_user_id(_conn), do: nil

  @doc """
  GET /api/v1/apps/verify_credentials
  Gets compact non-secret representation of the app. Supports app tokens and user tokens.
  """
  def verify_credentials(%{assigns: %{token: %Token{} = token}} = conn, _) do
    with %{app: %App{} = app} <- Repo.preload(token, :app) do
      render(conn, "compact_non_secret.json", app: app)
    end
  end
end
