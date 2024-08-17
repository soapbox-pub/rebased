# Pleroma: A lightweight social networking server
# Copyright © 2017-2023 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.AdminAPI.DomainController do
  @cachex Pleroma.Config.get([:cachex, :provider], Cachex)

  use Pleroma.Web, :controller

  alias Pleroma.Domain
  alias Pleroma.Web.AdminAPI
  alias Pleroma.Web.Plugs.OAuthScopesPlug

  import Pleroma.Web.ControllerHelper,
    only: [
      json_response: 3
    ]

  plug(Pleroma.Web.ApiSpec.CastAndValidate)

  plug(
    OAuthScopesPlug,
    %{scopes: ["admin:write"]}
    when action in [:create, :update, :delete]
  )

  plug(OAuthScopesPlug, %{scopes: ["admin:read"]} when action == :index)

  action_fallback(AdminAPI.FallbackController)

  defdelegate open_api_operation(action), to: Pleroma.Web.ApiSpec.Admin.DomainOperation

  def index(conn, _) do
    domains = Domain.list()

    render(conn, "index.json", domains: domains)
  end

  def create(%{body_params: params} = conn, _) do
    with {:domain_not_used, true} <-
           {:domain_not_used, params[:domain] !== Pleroma.Web.WebFinger.host()},
         {:ok, domain} <- Domain.create(params),
         _ <- @cachex.del(:domain_cache, :domains_list) do
      Pleroma.Workers.CheckDomainResolveWorker.new(%{
        "op" => "check_domain_resolve",
        "id" => domain.id
      })
      |> Oban.insert()

      render(conn, "show.json", domain: domain)
    else
      {:domain_not_used, false} ->
        {:error, :invalid_domain}

      {:error, changeset} ->
        errors = Map.new(changeset.errors, fn {key, {error, _}} -> {key, error} end)

        {:errors, errors}
    end
  end

  def update(%{body_params: params} = conn, %{id: id}) do
    {:ok, domain} =
      params
      |> Domain.update(id)

    @cachex.del(:domain_cache, :domains_list)

    render(conn, "show.json", domain: domain)
  end

  def delete(conn, %{id: id}) do
    with {:ok, _} <- Domain.delete(id),
         _ <- @cachex.del(:domain_cache, :domains_list) do
      json(conn, %{})
    else
      _ -> json_response(conn, :bad_request, "")
    end
  end
end
