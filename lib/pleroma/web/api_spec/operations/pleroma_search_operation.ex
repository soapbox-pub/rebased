# Pleroma: A lightweight social networking server
# Copyright © 2017-2022 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.ApiSpec.PleromaSearchOperation do
  alias OpenApiSpex.Operation
  alias OpenApiSpex.Schema
  alias Pleroma.Web.ApiSpec.Schemas.LocationResult

  def open_api_operation(action) do
    operation = String.to_existing_atom("#{action}_operation")
    apply(__MODULE__, operation, [])
  end

  def location_operation do
    %Operation{
      tags: ["Search"],
      summary: "Search locations",
      security: [%{"oAuth" => []}],
      operationId: "PleromaAPI.SearchController.location",
      parameters: [
        Operation.parameter(
          :q,
          :query,
          %Schema{type: :string},
          "What to search for",
          required: true
        ),
        Operation.parameter(
          :locale,
          :query,
          %Schema{type: :string},
          "The user's locale. Geocoding backends will make use of this value"
        ),
        Operation.parameter(
          :type,
          :query,
          %Schema{type: :string, enum: ["ADMINISTRATIVE"]},
          "Filter by type of results"
        )
      ],
      responses: %{
        200 => Operation.response("Results", "application/json", location_results())
      }
    }
  end

  def location_results do
    %Schema{
      type: :array,
      items: LocationResult,
      description: "Locations which match the given query",
      example: [LocationResult.schema().example]
    }
  end
end
