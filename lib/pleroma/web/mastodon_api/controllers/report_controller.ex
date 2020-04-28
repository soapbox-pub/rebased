# Pleroma: A lightweight social networking server
# Copyright © 2017-2020 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.MastodonAPI.ReportController do
  alias Pleroma.Plugs.OAuthScopesPlug

  use Pleroma.Web, :controller

  action_fallback(Pleroma.Web.MastodonAPI.FallbackController)

  plug(OpenApiSpex.Plug.CastAndValidate, render_error: Pleroma.Web.ApiSpec.RenderError)
  plug(OAuthScopesPlug, %{scopes: ["write:reports"]} when action == :create)
  plug(Pleroma.Plugs.EnsurePublicOrAuthenticatedPlug)

  defdelegate open_api_operation(action), to: Pleroma.Web.ApiSpec.ReportOperation

  @doc "POST /api/v1/reports"
  def create(%{assigns: %{user: user}, body_params: params} = conn, _) do
    with {:ok, activity} <- Pleroma.Web.CommonAPI.report(user, params) do
      render(conn, "show.json", activity: activity)
    end
  end
end
