# Pleroma: A lightweight social networking server
# Copyright © 2017-2022 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.ApiSpec.PleromaEventOperation do
  alias OpenApiSpex.Operation
  alias OpenApiSpex.Schema
  alias Pleroma.Web.ApiSpec.Schemas.ApiError
  alias Pleroma.Web.ApiSpec.Schemas.FlakeID
  alias Pleroma.Web.ApiSpec.Schemas.Status

  import Pleroma.Web.ApiSpec.Helpers

  def open_api_operation(action) do
    operation = String.to_existing_atom("#{action}_operation")
    apply(__MODULE__, operation, [])
  end

  def create_operation do
    %Operation{
      tags: ["Event actions"],
      summary: "Publish new status",
      security: [%{"oAuth" => ["write"]}],
      description: "Create a new event",
      operationId: "PleromaAPI.EventController.create",
      requestBody: request_body("Parameters", create_request(), required: true),
      responses: %{
        200 => event_response(),
        422 => Operation.response("Bad Request", "application/json", ApiError)
      }
    }
  end

  def participate_operation do
    %Operation{
      tags: ["Event actions"],
      summary: "Participate",
      security: [%{"oAuth" => ["write"]}],
      description: "Participate in an event",
      operationId: "PleromaAPI.EventController.participate",
      parameters: [id_param()],
      responses: %{
        200 => event_response(),
        404 => Operation.response("Not Found", "application/json", ApiError)
      }
    }
  end

  defp create_request do
    %Schema{
      title: "EventCreateRequest",
      type: :object,
      properties: %{
        name: %Schema{
          type: :string,
          description: "Name of the event."
        },
        content: %Schema{
          type: :string,
          description: "Text description of the event."
        },
        start_time: %Schema{
          type: :string,
          format: :"date-time",
          description: "Start time."
        },
        end_time: %Schema{
          type: :string,
          format: :"date-time",
          description: "End time."
        },
        join_mode: %Schema{
          type: :string,
          enum: ["free", "restricted"]
        }
      },
      example: %{
        "name" => "Example event",
        "content" => "No information for now.",
        "start_time" => "21-02-2022 22:00:00",
        "end_time" => "21-02-2022 23:00:00"
      }
    }
  end

  defp event_response do
    Operation.response(
      "Status",
      "application/json",
      Status
    )
  end

  defp id_param do
    Operation.parameter(:id, :path, FlakeID, "Event ID",
      example: "9umDrYheeY451cQnEe",
      required: true
    )
  end
end
