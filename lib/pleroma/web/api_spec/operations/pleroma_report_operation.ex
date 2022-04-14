# Pleroma: A lightweight social networking server
# Copyright © 2017-2022 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.ApiSpec.PleromaReportOperation do
  alias OpenApiSpex.Operation
  alias OpenApiSpex.Schema
  alias Pleroma.Web.ApiSpec.Admin.ReportOperation
  alias Pleroma.Web.ApiSpec.Schemas.Account
  alias Pleroma.Web.ApiSpec.Schemas.ApiError
  alias Pleroma.Web.ApiSpec.Schemas.FlakeID
  alias Pleroma.Web.ApiSpec.Schemas.Status

  def open_api_operation(action) do
    operation = String.to_existing_atom("#{action}_operation")
    apply(__MODULE__, operation, [])
  end

  def index_operation do
    %Operation{
      tags: ["Reports"],
      summary: "Get a list of your own reports",
      operationId: "PleromaAPI.ReportController.index",
      security: [%{"oAuth" => ["read:reports"]}],
      parameters: [
        Operation.parameter(
          :state,
          :query,
          ReportOperation.report_state(),
          "Filter by report state"
        ),
        Operation.parameter(
          :limit,
          :query,
          %Schema{type: :integer},
          "The number of records to retrieve"
        ),
        Operation.parameter(
          :page,
          :query,
          %Schema{type: :integer, default: 1},
          "Page number"
        ),
        Operation.parameter(
          :page_size,
          :query,
          %Schema{type: :integer, default: 50},
          "Number number of log entries per page"
        )
      ],
      responses: %{
        200 =>
          Operation.response("Response", "application/json", %Schema{
            type: :object,
            properties: %{
              total: %Schema{type: :integer},
              reports: %Schema{
                type: :array,
                items: report()
              }
            }
          }),
        404 => Operation.response("Not Found", "application/json", ApiError)
      }
    }
  end

  def show_operation do
    %Operation{
      tags: ["Reports"],
      summary: "Get an individual report",
      operationId: "PleromaAPI.ReportController.show",
      parameters: [ReportOperation.id_param()],
      security: [%{"oAuth" => ["read:reports"]}],
      responses: %{
        200 => Operation.response("Report", "application/json", report()),
        404 => Operation.response("Not Found", "application/json", ApiError)
      }
    }
  end

  # Copied from ReportOperation.report with removing notes
  defp report do
    %Schema{
      type: :object,
      properties: %{
        id: FlakeID,
        state: ReportOperation.report_state(),
        account: Account,
        actor: Account,
        content: %Schema{type: :string},
        created_at: %Schema{type: :string, format: :"date-time"},
        statuses: %Schema{type: :array, items: Status}
      }
    }
  end
end
