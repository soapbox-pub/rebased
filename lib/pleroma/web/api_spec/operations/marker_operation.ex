# Pleroma: A lightweight social networking server
# Copyright © 2017-2020 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.ApiSpec.MarkerOperation do
  alias OpenApiSpex.Operation
  alias OpenApiSpex.Schema
  alias Pleroma.Web.ApiSpec.Helpers
  alias Pleroma.Web.ApiSpec.Schemas.MarkersResponse
  alias Pleroma.Web.ApiSpec.Schemas.MarkersUpsertRequest

  def open_api_operation(action) do
    operation = String.to_existing_atom("#{action}_operation")
    apply(__MODULE__, operation, [])
  end

  def index_operation do
    %Operation{
      tags: ["markers"],
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
        200 => Operation.response("Marker", "application/json", MarkersResponse)
      }
    }
  end

  def upsert_operation do
    %Operation{
      tags: ["markers"],
      summary: "Save position in timeline",
      operationId: "MarkerController.upsert",
      requestBody: Helpers.request_body("Parameters", MarkersUpsertRequest, required: true),
      security: [%{"oAuth" => ["follow", "write:blocks"]}],
      responses: %{
        200 => Operation.response("Marker", "application/json", MarkersResponse)
      }
    }
  end
end
