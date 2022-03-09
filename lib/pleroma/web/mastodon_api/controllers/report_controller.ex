# Pleroma: A lightweight social networking server
# Copyright © 2017-2022 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.MastodonAPI.ReportController do
  use Pleroma.Web, :controller

  action_fallback(Pleroma.Web.MastodonAPI.FallbackController)

  plug(Pleroma.Web.ApiSpec.CastAndValidate)
  plug(Pleroma.Web.Plugs.OAuthScopesPlug, %{scopes: ["write:reports"]} when action == :create)

  defdelegate open_api_operation(action), to: Pleroma.Web.ApiSpec.ReportOperation

  @doc "POST /api/v1/reports"
  def create(%{assigns: %{user: user}, body_params: params} = conn, _) do
    with {:ok, activity} <- Pleroma.Web.CommonAPI.report(user, params) do
      render(conn, "show.json", activity: activity)
    end
  end
end
