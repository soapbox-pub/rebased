# Pleroma: A lightweight social networking server
# Copyright © 2017-2020 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.AdminAPI.ReportController do
  use Pleroma.Web, :controller

  import Pleroma.Web.ControllerHelper, only: [json_response: 3]

  alias Pleroma.Activity
  alias Pleroma.ModerationLog
  alias Pleroma.Plugs.OAuthScopesPlug
  alias Pleroma.ReportNote
  alias Pleroma.Web.ActivityPub.Utils
  alias Pleroma.Web.AdminAPI
  alias Pleroma.Web.AdminAPI.Report
  alias Pleroma.Web.CommonAPI

  require Logger

  @users_page_size 50

  plug(OAuthScopesPlug, %{scopes: ["read:reports"], admin: true} when action in [:index, :show])

  plug(
    OAuthScopesPlug,
    %{scopes: ["write:reports"], admin: true}
    when action in [:update, :notes_create, :notes_delete]
  )

  action_fallback(AdminAPI.FallbackController)

  def index(conn, params) do
    {page, page_size} = page_params(params)

    reports = Utils.get_reports(params, page, page_size)

    render(conn, "index.json", reports: reports)
  end

  def show(conn, %{"id" => id}) do
    with %Activity{} = report <- Activity.get_by_id(id) do
      render(conn, "show.json", Report.extract_report_info(report))
    else
      _ -> {:error, :not_found}
    end
  end

  def update(%{assigns: %{user: admin}} = conn, %{"reports" => reports}) do
    result =
      reports
      |> Enum.map(fn report ->
        with {:ok, activity} <- CommonAPI.update_report_state(report["id"], report["state"]) do
          ModerationLog.insert_log(%{
            action: "report_update",
            actor: admin,
            subject: activity
          })

          activity
        else
          {:error, message} -> %{id: report["id"], error: message}
        end
      end)

    case Enum.any?(result, &Map.has_key?(&1, :error)) do
      true -> json_response(conn, :bad_request, result)
      false -> json_response(conn, :no_content, "")
    end
  end

  def notes_create(%{assigns: %{user: user}} = conn, %{
        "id" => report_id,
        "content" => content
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
        "id" => note_id,
        "report_id" => report_id
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

  defp page_params(params) do
    {get_page(params["page"]), get_page_size(params["page_size"])}
  end

  defp get_page(page_string) when is_nil(page_string), do: 1

  defp get_page(page_string) do
    case Integer.parse(page_string) do
      {page, _} -> page
      :error -> 1
    end
  end

  defp get_page_size(page_size_string) when is_nil(page_size_string), do: @users_page_size

  defp get_page_size(page_size_string) do
    case Integer.parse(page_size_string) do
      {page_size, _} -> page_size
      :error -> @users_page_size
    end
  end
end
