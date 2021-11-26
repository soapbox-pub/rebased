# Pleroma: A lightweight social networking server
# Copyright © 2017-2021 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.MastodonAPI.SuggestionController do
  use Pleroma.Web, :controller
  alias Pleroma.User

  require Logger

  plug(Pleroma.Web.ApiSpec.CastAndValidate)
  plug(Pleroma.Web.Plugs.OAuthScopesPlug, %{scopes: ["read"]} when action in [:index, :index2])

  def open_api_operation(action) do
    operation = String.to_existing_atom("#{action}_operation")
    apply(__MODULE__, operation, [])
  end

  def index_operation do
    %OpenApiSpex.Operation{
      tags: ["Suggestions"],
      summary: "Follow suggestions (Not implemented)",
      operationId: "SuggestionController.index",
      responses: %{
        200 => Pleroma.Web.ApiSpec.Helpers.empty_array_response()
      }
    }
  end

  def index2_operation do
    %OpenApiSpex.Operation{
      tags: ["Suggestions"],
      summary: "Follow suggestions",
      operationId: "SuggestionController.index2",
      responses: %{
        200 => Pleroma.Web.ApiSpec.Helpers.empty_array_response()
      }
    }
  end

  @doc "GET /api/v1/suggestions"
  def index(conn, params),
    do: Pleroma.Web.MastodonAPI.MastodonAPIController.empty_array(conn, params)

  @doc "GET /api/v2/suggestions"
  def index2(%{assigns: %{user: user}} = conn, params) do
    limit = Map.get(params, :limit, 40) |> min(80)

    users =
      %{is_suggested: true, limit: limit}
      |> User.Query.build()
      |> Pleroma.Repo.all()

    render(conn, "index.json", %{users: users, source: :staff, for: user})
  end
end
