# Pleroma: A lightweight social networking server
# Copyright © 2017-2022 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.ApiSpec.Admin.ReportOperation do
  alias OpenApiSpex.Operation
  alias OpenApiSpex.Schema
  alias Pleroma.Web.ApiSpec.Schemas.Account
  alias Pleroma.Web.ApiSpec.Schemas.ApiError
  alias Pleroma.Web.ApiSpec.Schemas.FlakeID
  alias Pleroma.Web.ApiSpec.Schemas.Status

  import Pleroma.Web.ApiSpec.Helpers

  def open_api_operation(action) do
    operation = String.to_existing_atom("#{action}_operation")
    apply(__MODULE__, operation, [])
  end

  def index_operation do
    %Operation{
      tags: ["Report managment"],
      summary: "Retrieve a list of reports",
      operationId: "AdminAPI.ReportController.index",
      security: [%{"oAuth" => ["admin:read:reports"]}],
      parameters: [
        Operation.parameter(
          :state,
          :query,
          report_state(),
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
        | admin_api_params()
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
        403 => Operation.response("Forbidden", "application/json", ApiError)
      }
    }
  end

  def show_operation do
    %Operation{
      tags: ["Report managment"],
      summary: "Retrieve a report",
      operationId: "AdminAPI.ReportController.show",
      parameters: [id_param() | admin_api_params()],
      security: [%{"oAuth" => ["admin:read:reports"]}],
      responses: %{
        200 => Operation.response("Report", "application/json", report()),
        404 => Operation.response("Not Found", "application/json", ApiError)
      }
    }
  end

  def update_operation do
    %Operation{
      tags: ["Report managment"],
      summary: "Change state of specified reports",
      operationId: "AdminAPI.ReportController.update",
      security: [%{"oAuth" => ["admin:write:reports"]}],
      parameters: admin_api_params(),
      requestBody: request_body("Parameters", update_request(), required: true),
      responses: %{
        204 => no_content_response(),
        400 => Operation.response("Bad Request", "application/json", update_400_response()),
        403 => Operation.response("Forbidden", "application/json", ApiError)
      }
    }
  end

  def notes_create_operation do
    %Operation{
      tags: ["Report managment"],
      summary: "Add a note to the report",
      operationId: "AdminAPI.ReportController.notes_create",
      parameters: [id_param() | admin_api_params()],
      requestBody:
        request_body("Parameters", %Schema{
          type: :object,
          properties: %{
            content: %Schema{type: :string, description: "The message"}
          }
        }),
      security: [%{"oAuth" => ["admin:write:reports"]}],
      responses: %{
        204 => no_content_response(),
        404 => Operation.response("Not Found", "application/json", ApiError)
      }
    }
  end

  def notes_delete_operation do
    %Operation{
      tags: ["Report managment"],
      summary: "Delete note attached to the report",
      operationId: "AdminAPI.ReportController.notes_delete",
      parameters: [
        Operation.parameter(:report_id, :path, :string, "Report ID"),
        Operation.parameter(:id, :path, :string, "Note ID")
        | admin_api_params()
      ],
      security: [%{"oAuth" => ["admin:write:reports"]}],
      responses: %{
        204 => no_content_response(),
        404 => Operation.response("Not Found", "application/json", ApiError)
      }
    }
  end

  def report_state do
    %Schema{type: :string, enum: ["open", "closed", "resolved"]}
  end

  def id_param do
    Operation.parameter(:id, :path, FlakeID, "Report ID",
      example: "9umDrYheeY451cQnEe",
      required: true
    )
  end

  defp report do
    %Schema{
      type: :object,
      properties: %{
        id: FlakeID,
        state: report_state(),
        account: account_admin(),
        actor: account_admin(),
        content: %Schema{type: :string},
        created_at: %Schema{type: :string, format: :"date-time"},
        statuses: %Schema{type: :array, items: Status},
        notes: %Schema{
          type: :array,
          items: %Schema{
            type: :object,
            properties: %{
              id: %Schema{type: :integer},
              user_id: FlakeID,
              content: %Schema{type: :string},
              inserted_at: %Schema{type: :string, format: :"date-time"}
            }
          }
        },
        rules: %Schema{
          type: :array,
          items: %Schema{
            type: :object,
            properties: %{
              id: %Schema{type: :integer},
              text: %Schema{type: :string}
            }
          }
        }
      }
    }
  end

  defp account_admin do
    %Schema{
      title: "Account",
      description: "Account view for admins",
      type: :object,
      properties:
        Map.merge(Account.schema().properties, %{
          nickname: %Schema{type: :string},
          is_active: %Schema{type: :boolean},
          local: %Schema{type: :boolean},
          roles: %Schema{
            type: :object,
            properties: %{
              admin: %Schema{type: :boolean},
              moderator: %Schema{type: :boolean}
            }
          },
          is_confirmed: %Schema{type: :boolean}
        })
    }
  end

  defp update_request do
    %Schema{
      type: :object,
      required: [:reports],
      properties: %{
        reports: %Schema{
          type: :array,
          items: %Schema{
            type: :object,
            properties: %{
              id: %Schema{allOf: [FlakeID], description: "Required, report ID"},
              state: %Schema{
                type: :string,
                description:
                  "Required, the new state. Valid values are `open`, `closed` and `resolved`"
              }
            }
          },
          example: %{
            "reports" => [
              %{"id" => "123", "state" => "closed"},
              %{"id" => "1337", "state" => "resolved"}
            ]
          }
        }
      }
    }
  end

  defp update_400_response do
    %Schema{
      type: :array,
      items: %Schema{
        type: :object,
        properties: %{
          id: %Schema{allOf: [FlakeID], description: "Report ID"},
          error: %Schema{type: :string, description: "Error message"}
        }
      }
    }
  end
end
