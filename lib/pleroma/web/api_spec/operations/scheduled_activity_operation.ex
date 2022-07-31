# Pleroma: A lightweight social networking server
# Copyright © 2017-2022 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.ApiSpec.ScheduledActivityOperation do
  alias OpenApiSpex.Operation
  alias OpenApiSpex.Schema
  alias Pleroma.Web.ApiSpec.Schemas.ApiError
  alias Pleroma.Web.ApiSpec.Schemas.FlakeID
  alias Pleroma.Web.ApiSpec.Schemas.ScheduledStatus

  import Pleroma.Web.ApiSpec.Helpers

  def open_api_operation(action) do
    operation = String.to_existing_atom("#{action}_operation")
    apply(__MODULE__, operation, [])
  end

  def index_operation do
    %Operation{
      tags: ["Scheduled statuses"],
      summary: "View scheduled statuses",
      security: [%{"oAuth" => ["read:statuses"]}],
      parameters: pagination_params(),
      operationId: "ScheduledActivity.index",
      responses: %{
        200 =>
          Operation.response("Array of ScheduledStatus", "application/json", %Schema{
            type: :array,
            items: ScheduledStatus
          })
      }
    }
  end

  def show_operation do
    %Operation{
      tags: ["Scheduled statuses"],
      summary: "View a single scheduled status",
      security: [%{"oAuth" => ["read:statuses"]}],
      parameters: [id_param()],
      operationId: "ScheduledActivity.show",
      responses: %{
        200 => Operation.response("Scheduled Status", "application/json", ScheduledStatus),
        404 => Operation.response("Error", "application/json", ApiError)
      }
    }
  end

  def update_operation do
    %Operation{
      tags: ["Scheduled statuses"],
      summary: "Schedule a status",
      operationId: "ScheduledActivity.update",
      security: [%{"oAuth" => ["write:statuses"]}],
      parameters: [id_param()],
      requestBody:
        request_body("Parameters", %Schema{
          type: :object,
          properties: %{
            scheduled_at: %Schema{
              type: :string,
              format: :"date-time",
              description:
                "ISO 8601 Datetime at which the status will be published. Must be at least 5 minutes into the future."
            }
          }
        }),
      responses: %{
        200 => Operation.response("Scheduled Status", "application/json", ScheduledStatus),
        404 => Operation.response("Error", "application/json", ApiError)
      }
    }
  end

  def delete_operation do
    %Operation{
      tags: ["Scheduled statuses"],
      summary: "Cancel a scheduled status",
      security: [%{"oAuth" => ["write:statuses"]}],
      parameters: [id_param()],
      operationId: "ScheduledActivity.delete",
      responses: %{
        200 => Operation.response("Empty object", "application/json", %Schema{type: :object}),
        404 => Operation.response("Error", "application/json", ApiError)
      }
    }
  end

  defp id_param do
    Operation.parameter(:id, :path, FlakeID, "Poll ID",
      example: "123",
      required: true
    )
  end
end
