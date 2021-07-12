# Pleroma: A lightweight social networking server
# Copyright © 2017-2021 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.AdminAPI.OAuthAppController do
  use Pleroma.Web, :controller

  import Pleroma.Web.ControllerHelper, only: [json_response: 3]

  alias Pleroma.Web.OAuth.App
  alias Pleroma.Web.Plugs.OAuthScopesPlug

  require Logger

  plug(Pleroma.Web.ApiSpec.CastAndValidate)

  plug(
    OAuthScopesPlug,
    %{scopes: ["admin:write"]}
    when action in [:create, :index, :update, :delete]
  )

  action_fallback(Pleroma.Web.AdminAPI.FallbackController)

  defdelegate open_api_operation(action), to: Pleroma.Web.ApiSpec.Admin.OAuthAppOperation

  def index(conn, params) do
    search_params =
      params
      |> Map.take([:client_id, :page, :page_size, :trusted])
      |> Map.put(:client_name, params[:name])

    with {:ok, apps, count} <- App.search(search_params) do
      render(conn, "index.json",
        apps: apps,
        count: count,
        page_size: params.page_size,
        admin: true
      )
    end
  end

  def create(%{body_params: params} = conn, _) do
    params = Pleroma.Maps.put_if_present(params, :client_name, params[:name])

    case App.create(params) do
      {:ok, app} ->
        render(conn, "show.json", app: app, admin: true)

      {:error, changeset} ->
        json(conn, App.errors(changeset))
    end
  end

  def update(%{body_params: params} = conn, %{id: id}) do
    params = Pleroma.Maps.put_if_present(params, :client_name, params[:name])

    with {:ok, app} <- App.update(id, params) do
      render(conn, "show.json", app: app, admin: true)
    else
      {:error, changeset} ->
        json(conn, App.errors(changeset))

      nil ->
        json_response(conn, :bad_request, "")
    end
  end

  def delete(conn, params) do
    with {:ok, _app} <- App.destroy(params.id) do
      json_response(conn, :no_content, "")
    else
      _ -> json_response(conn, :bad_request, "")
    end
  end
end
