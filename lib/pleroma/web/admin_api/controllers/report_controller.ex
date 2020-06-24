# Pleroma: A lightweight social networking server
# Copyright © 2017-2020 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.AdminAPI.ReportController do
  use Pleroma.Web, :controller

  import Pleroma.Web.ControllerHelper, only: [json_response: 3]

  alias Pleroma.Activity
  alias Pleroma.ModerationLog
  alias Pleroma.ReportNote
  alias Pleroma.Web.ActivityPub.Utils
  alias Pleroma.Web.AdminAPI
  alias Pleroma.Web.AdminAPI.Report
  alias Pleroma.Web.CommonAPI
  alias Pleroma.Web.Plugs.OAuthScopesPlug

  require Logger

  plug(Pleroma.Web.ApiSpec.CastAndValidate)
  plug(OAuthScopesPlug, %{scopes: ["read:reports"], admin: true} when action in [:index, :show])

  plug(
    OAuthScopesPlug,
    %{scopes: ["write:reports"], admin: true}
    when action in [:update, :notes_create, :notes_delete]
  )

  action_fallback(AdminAPI.FallbackController)

  defdelegate open_api_operation(action), to: Pleroma.Web.ApiSpec.Admin.ReportOperation

  def index(conn, params) do
    reports = Utils.get_reports(params, params.page, params.page_size)

    render(conn, "index.json", reports: reports)
  end

  def show(conn, %{id: id}) do
    with %Activity{} = report <- Activity.get_by_id(id) do
      render(conn, "show.json", Report.extract_report_info(report))
    else
      _ -> {:error, :not_found}
    end
  end

  def update(%{assigns: %{user: admin}, body_params: %{reports: reports}} = conn, _) do
    result =
      Enum.map(reports, fn report ->
        case CommonAPI.update_report_state(report.id, report.state) do
          {:ok, activity} ->
            ModerationLog.insert_log(%{
              action: "report_update",
              actor: admin,
              subject: activity
            })

            activity

          {:error, message} ->
            %{id: report.id, error: message}
        end
      end)

    if Enum.any?(result, &Map.has_key?(&1, :error)) do
      json_response(conn, :bad_request, result)
    else
      json_response(conn, :no_content, "")
    end
  end

  def notes_create(%{assigns: %{user: user}, body_params: %{content: content}} = conn, %{
        id: report_id
      }) do
    with {:ok, _} <- ReportNote.create(user.id, report_id, content) do
      ModerationLog.insert_log(%{
        action: "report_note",
        actor: user,
        subject: Activity.get_by_id(report_id),
        text: content
      })

      json_response(conn, :no_content, "")
    else
      _ -> json_response(conn, :bad_request, "")
    end
  end

  def notes_delete(%{assigns: %{user: user}} = conn, %{
        id: note_id,
        report_id: report_id
      }) do
    with {:ok, note} <- ReportNote.destroy(note_id) do
      ModerationLog.insert_log(%{
        action: "report_note_delete",
        actor: user,
        subject: Activity.get_by_id(report_id),
        text: note.content
      })

      json_response(conn, :no_content, "")
    else
      _ -> json_response(conn, :bad_request, "")
    end
  end
end
