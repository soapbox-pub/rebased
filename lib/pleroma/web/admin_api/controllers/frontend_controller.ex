# Pleroma: A lightweight social networking server
# Copyright © 2017-2022 Pleroma Authors <https://pleroma.social/>
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

    # FIrst get frontends from config,
    # then add frontends that are installed but not in the config
    frontends =
      Config.get([:frontends, :available], [])
      |> Enum.map(fn {name, desc} ->
        desc
        |> Map.put("installed", name in installed)
        |> Map.put("installed_refs", installed_refs(name))
      end)

    frontends =
      frontends ++
        (installed
         |> Enum.filter(fn n -> not Enum.any?(frontends, fn f -> f["name"] == n end) end)
         |> Enum.map(fn name ->
           %{"name" => name, "installed" => true, "installed_refs" => installed_refs(name)}
         end))

    render(conn, "index.json", frontends: frontends)
  end

  def install(%{body_params: params} = conn, _params) do
    with %Frontend{} = frontend <- params_to_frontend(params),
         %Frontend{} <- Frontend.install(frontend) do
      index(conn, %{})
    end
  end

  defp installed do
    frontend_directory = Pleroma.Frontend.dir()

    if File.exists?(frontend_directory) do
      File.ls!(frontend_directory)
    else
      []
    end
  end

  defp params_to_frontend(params) when is_map(params) do
    struct(Frontend, params)
  end

  def installed_refs(name) do
    if name in installed() do
      File.ls!(Path.join(Pleroma.Frontend.dir(), name))
    else
      []
    end
  end
end
