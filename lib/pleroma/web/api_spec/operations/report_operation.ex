# Pleroma: A lightweight social networking server
# Copyright © 2017-2021 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.ApiSpec.ReportOperation do
  alias OpenApiSpex.Operation
  alias OpenApiSpex.Schema
  alias Pleroma.Web.ApiSpec.Helpers
  alias Pleroma.Web.ApiSpec.Schemas.ApiError
  alias Pleroma.Web.ApiSpec.Schemas.BooleanLike

  def open_api_operation(action) do
    operation = String.to_existing_atom("#{action}_operation")
    apply(__MODULE__, operation, [])
  end

  def create_operation do
    %Operation{
      tags: ["Reports"],
      summary: "File a report",
      description: "Report problematic users to your moderators",
      operationId: "ReportController.create",
      security: [%{"oAuth" => ["follow", "write:reports"]}],
      requestBody: Helpers.request_body("Parameters", create_request(), required: true),
      responses: %{
        200 => Operation.response("Report", "application/json", create_response()),
        400 => Operation.response("Report", "application/json", ApiError)
      }
    }
  end

  defp create_request do
    %Schema{
      title: "ReportCreateRequest",
      description: "POST body for creating a report",
      type: :object,
      properties: %{
        account_id: %Schema{type: :string, description: "ID of the account to report"},
        status_ids: %Schema{
          type: :array,
          nullable: true,
          items: %Schema{type: :string},
          description: "Array of Statuses to attach to the report, for context"
        },
        comment: %Schema{
          type: :string,
          nullable: true,
          description: "Reason for the report"
        },
        forward: %Schema{
          allOf: [BooleanLike],
          nullable: true,
          default: false,
          description:
            "If the account is remote, should the report be forwarded to the remote admin?"
        }
      },
      required: [:account_id],
      example: %{
        "account_id" => "123",
        "status_ids" => ["1337"],
        "comment" => "bad status!",
        "forward" => "false"
      }
    }
  end

  defp create_response do
    %Schema{
      title: "ReportResponse",
      type: :object,
      properties: %{
        id: %Schema{type: :string, description: "Report ID"},
        action_taken: %Schema{type: :boolean, description: "Is action taken?"}
      },
      example: %{
        "id" => "123",
        "action_taken" => false
      }
    }
  end
end
