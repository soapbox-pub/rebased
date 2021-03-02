# Pleroma: A lightweight social networking server
# Copyright © 2017-2021 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.PleromaAPI.ReportController do
  use Pleroma.Web, :controller

  alias Pleroma.Activity
  alias Pleroma.Web.ActivityPub.Utils
  alias Pleroma.Web.AdminAPI.Report

  action_fallback(Pleroma.Web.MastodonAPI.FallbackController)
  plug(Pleroma.Web.ApiSpec.CastAndValidate)
  plug(Pleroma.Web.Plugs.OAuthScopesPlug, %{scopes: ["read:reports"]})

  defdelegate open_api_operation(action), to: Pleroma.Web.ApiSpec.PleromaReportOperation

  @doc "GET /api/v0/pleroma/reports"
  def index(%{assigns: %{user: user}, body_params: params} = conn, _) do
    params =
      params
      |> Map.put(:actor_id, user.ap_id)

    reports = Utils.get_reports(params, Map.get(params, :page, 1), Map.get(params, :size, 20))

    render(conn, "index.json", %{reports: reports, for: user})
  end

  @doc "GET /api/v0/pleroma/reports/:id"
  def show(%{assigns: %{user: user}} = conn, %{id: id}) do
    with %Activity{} = report <- Activity.get_report(id),
         true <- report.actor == user.ap_id,
         %{} = report_info <- Report.extract_report_info(report) do
      render(conn, "show.json", Map.put(report_info, :for, user))
    else
      false ->
        {:error, :not_found}

      nil ->
        {:error, :not_found}

      e ->
        {:error, inspect(e)}
    end
  end
end
