# Pleroma: A lightweight social networking server
# Copyright © 2017-2020 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.ApiSpec.FilterOperation do
  alias OpenApiSpex.Operation
  alias OpenApiSpex.Schema
  alias Pleroma.Web.ApiSpec.Helpers
  alias Pleroma.Web.ApiSpec.Schemas.Filter
  alias Pleroma.Web.ApiSpec.Schemas.FilterCreateRequest
  alias Pleroma.Web.ApiSpec.Schemas.FiltersResponse
  alias Pleroma.Web.ApiSpec.Schemas.FilterUpdateRequest

  def open_api_operation(action) do
    operation = String.to_existing_atom("#{action}_operation")
    apply(__MODULE__, operation, [])
  end

  def index_operation do
    %Operation{
      tags: ["apps"],
      summary: "View all filters",
      operationId: "FilterController.index",
      security: [%{"oAuth" => ["read:filters"]}],
      responses: %{
        200 => Operation.response("Filters", "application/json", FiltersResponse)
      }
    }
  end

  def create_operation do
    %Operation{
      tags: ["apps"],
      summary: "Create a filter",
      operationId: "FilterController.create",
      requestBody: Helpers.request_body("Parameters", FilterCreateRequest, required: true),
      security: [%{"oAuth" => ["write:filters"]}],
      responses: %{200 => Operation.response("Filter", "application/json", Filter)}
    }
  end

  def show_operation do
    %Operation{
      tags: ["apps"],
      summary: "View all filters",
      parameters: [id_param()],
      operationId: "FilterController.show",
      security: [%{"oAuth" => ["read:filters"]}],
      responses: %{
        200 => Operation.response("Filter", "application/json", Filter)
      }
    }
  end

  def update_operation do
    %Operation{
      tags: ["apps"],
      summary: "Update a filter",
      parameters: [id_param()],
      operationId: "FilterController.update",
      requestBody: Helpers.request_body("Parameters", FilterUpdateRequest, required: true),
      security: [%{"oAuth" => ["write:filters"]}],
      responses: %{
        200 => Operation.response("Filter", "application/json", Filter)
      }
    }
  end

  def delete_operation do
    %Operation{
      tags: ["apps"],
      summary: "Remove a filter",
      parameters: [id_param()],
      operationId: "FilterController.delete",
      security: [%{"oAuth" => ["write:filters"]}],
      responses: %{
        200 =>
          Operation.response("Filter", "application/json", %Schema{
            type: :object,
            description: "Empty object"
          })
      }
    }
  end

  defp id_param do
    Operation.parameter(:id, :path, :string, "Filter ID", example: "123", required: true)
  end
end
