# Pleroma: A lightweight social networking server
# Copyright © 2017-2022 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.AdminAPI.RuleController do
  use Pleroma.Web, :controller

  alias Pleroma.Repo
  alias Pleroma.Rule
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

  defdelegate open_api_operation(action), to: Pleroma.Web.ApiSpec.Admin.RuleOperation

  def index(conn, _) do
    rules =
      Rule.query()
      |> Repo.all()

    render(conn, "index.json", rules: rules)
  end

  def create(%{body_params: params} = conn, _) do
    rule =
      params
      |> Rule.create()

    render(conn, "show.json", rule: rule)
  end

  def update(%{body_params: params} = conn, %{id: id}) do
    rule =
      params
      |> Rule.update(id)

    render(conn, "show.json", rule: rule)
  end

  def delete(conn, %{id: id}) do
    with {:ok, _} <- Rule.delete(id) do
      json(conn, %{})
    else
      _ -> json_response(conn, :bad_request, "")
    end
  end
end
