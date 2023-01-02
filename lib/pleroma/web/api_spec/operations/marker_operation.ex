# Pleroma: A lightweight social networking server
# Copyright © 2017-2022 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.ApiSpec.MarkerOperation do
  alias OpenApiSpex.Operation
  alias OpenApiSpex.Schema
  alias Pleroma.Web.ApiSpec.Helpers

  def open_api_operation(action) do
    operation = String.to_existing_atom("#{action}_operation")
    apply(__MODULE__, operation, [])
  end

  def index_operation do
    %Operation{
      tags: ["Markers"],
      summary: "Get saved timeline position",
      security: [%{"oAuth" => ["read:statuses"]}],
      operationId: "MarkerController.index",
      parameters: [
        Operation.parameter(
          :timeline,
          :query,
          %Schema{
            type: :array,
            items: %Schema{type: :string, enum: ["home", "notifications"]}
          },
          "Array of markers to fetch. If not provided, an empty object will be returned."
        )
      ],
      responses: %{
        200 => Operation.response("Marker", "application/json", response()),
        403 => Operation.response("Error", "application/json", api_error())
      }
    }
  end

  def upsert_operation do
    %Operation{
      tags: ["Markers"],
      summary: "Save position in timeline",
      operationId: "MarkerController.upsert",
      requestBody: Helpers.request_body("Parameters", upsert_request(), required: true),
      security: [%{"oAuth" => ["follow", "write:blocks"]}],
      responses: %{
        200 => Operation.response("Marker", "application/json", response()),
        403 => Operation.response("Error", "application/json", api_error())
      }
    }
  end

  defp marker do
    %Schema{
      title: "Marker",
      description: "Schema for a marker",
      type: :object,
      properties: %{
        last_read_id: %Schema{type: :string},
        version: %Schema{type: :integer},
        updated_at: %Schema{type: :string},
        pleroma: %Schema{
          type: :object,
          properties: %{
            unread_count: %Schema{type: :integer}
          }
        }
      },
      example: %{
        "last_read_id" => "35098814",
        "version" => 361,
        "updated_at" => "2019-11-26T22:37:25.239Z",
        "pleroma" => %{"unread_count" => 5}
      }
    }
  end

  defp response do
    %Schema{
      title: "MarkersResponse",
      description: "Response schema for markers",
      type: :object,
      properties: %{
        notifications: %Schema{allOf: [marker()], nullable: true},
        home: %Schema{allOf: [marker()], nullable: true}
      },
      items: %Schema{type: :string},
      example: %{
        "notifications" => %{
          "last_read_id" => "35098814",
          "version" => 361,
          "updated_at" => "2019-11-26T22:37:25.239Z",
          "pleroma" => %{"unread_count" => 0}
        },
        "home" => %{
          "last_read_id" => "103206604258487607",
          "version" => 468,
          "updated_at" => "2019-11-26T22:37:25.235Z",
          "pleroma" => %{"unread_count" => 10}
        }
      }
    }
  end

  defp upsert_request do
    %Schema{
      title: "MarkersUpsertRequest",
      description: "Request schema for marker upsert",
      type: :object,
      properties: %{
        notifications: %Schema{
          type: :object,
          nullable: true,
          properties: %{
            last_read_id: %Schema{nullable: true, type: :string}
          }
        },
        home: %Schema{
          type: :object,
          nullable: true,
          properties: %{
            last_read_id: %Schema{nullable: true, type: :string}
          }
        }
      },
      example: %{
        "home" => %{
          "last_read_id" => "103194548672408537",
          "version" => 462,
          "updated_at" => "2019-11-24T19:39:39.337Z"
        }
      }
    }
  end

  defp api_error do
    %Schema{
      type: :object,
      properties: %{error: %Schema{type: :string}}
    }
  end
end
