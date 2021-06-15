# Pleroma: A lightweight social networking server
# Copyright © 2017-2021 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.AdminAPI.FrontendController do
  use Pleroma.Web, :controller

  alias Pleroma.Config
  alias Pleroma.Frontend
  alias Pleroma.Web.Plugs.OAuthScopesPlug

  plug(Pleroma.Web.ApiSpec.CastAndValidate)
  plug(OAuthScopesPlug, %{scopes: ["admin:write"]} when action == :install)
  plug(OAuthScopesPlug, %{scopes: ["admin:read"]} when action == :index)
  action_fallback(Pleroma.Web.AdminAPI.FallbackController)

  defdelegate open_api_operation(action), to: Pleroma.Web.ApiSpec.Admin.FrontendOperation

  def index(conn, _params) do
    installed = installed()

    frontends =
      [:frontends, :available]
      |> Config.get([])
      |> Enum.map(fn {name, desc} ->
        Map.put(desc, "installed", name in installed)
      end)

    render(conn, "index.json", frontends: frontends)
  end

  def install(%{body_params: params} = conn, _params) do
    with %Frontend{} = frontend <- params_to_frontend(params),
         %Frontend{} <- Frontend.install(frontend) do
      index(conn, %{})
    end
  end

  defp installed do
    File.ls!(Frontend.dir())
  end

  defp params_to_frontend(params) when is_map(params) do
    struct(Frontend, params)
  end
end
