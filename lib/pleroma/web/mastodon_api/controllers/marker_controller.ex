# Pleroma: A lightweight social networking server
# Copyright © 2017-2020 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.MastodonAPI.MarkerController do
  use Pleroma.Web, :controller
  alias Pleroma.Plugs.OAuthScopesPlug

  plug(
    OAuthScopesPlug,
    %{scopes: ["read:statuses"]}
    when action == :index
  )

  plug(OAuthScopesPlug, %{scopes: ["write:statuses"]} when action == :upsert)

  action_fallback(Pleroma.Web.MastodonAPI.FallbackController)
  plug(OpenApiSpex.Plug.CastAndValidate)

  defdelegate open_api_operation(action), to: Pleroma.Web.ApiSpec.MarkerOperation

  # GET /api/v1/markers
  def index(%{assigns: %{user: user}} = conn, params) do
    markers = Pleroma.Marker.get_markers(user, params[:timeline])
    render(conn, "markers.json", %{markers: markers})
  end

  # POST /api/v1/markers
  def upsert(%{assigns: %{user: user}, body_params: params} = conn, _) do
    params =
      params
      |> Map.from_struct()
      |> Map.new(fn {key, value} -> {to_string(key), value} end)

    with {:ok, result} <- Pleroma.Marker.upsert(user, params),
         markers <- Map.values(result) do
      render(conn, "markers.json", %{markers: markers})
    end
  end
end
