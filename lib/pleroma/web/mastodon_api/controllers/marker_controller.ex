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
  plug(Pleroma.Plugs.EnsurePublicOrAuthenticatedPlug)
  action_fallback(Pleroma.Web.MastodonAPI.FallbackController)

  # GET /api/v1/markers
  def index(%{assigns: %{user: user}} = conn, params) do
    markers = Pleroma.Marker.get_markers(user, params["timeline"])
    render(conn, "markers.json", %{markers: markers})
  end

  # POST /api/v1/markers
  def upsert(%{assigns: %{user: user}} = conn, params) do
    with {:ok, result} <- Pleroma.Marker.upsert(user, params),
         markers <- Map.values(result) do
      render(conn, "markers.json", %{markers: markers})
    end
  end
end
