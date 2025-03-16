# Pleroma: A lightweight social networking server
# Copyright © 2017-2022 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.ApiSpec.Admin.DomainOperation do
  alias OpenApiSpex.Operation
  alias OpenApiSpex.Schema
  alias Pleroma.Web.ApiSpec.Schemas.ApiError

  import Pleroma.Web.ApiSpec.Helpers

  def open_api_operation(action) do
    operation = String.to_existing_atom("#{action}_operation")
    apply(__MODULE__, operation, [])
  end

  def index_operation do
    %Operation{
      tags: ["Domain management"],
      summary: "Retrieve list of domains",
      operationId: "AdminAPI.DomainController.index",
      security: [%{"oAuth" => ["admin:read"]}],
      responses: %{
        200 =>
          Operation.response("Response", "application/json", %Schema{
            type: :array,
            items: domain()
          }),
        403 => Operation.response("Forbidden", "application/json", ApiError)
      }
    }
  end

  def create_operation do
    %Operation{
      tags: ["Domain management"],
      summary: "Create new domain",
      operationId: "AdminAPI.DomainController.create",
      security: [%{"oAuth" => ["admin:write"]}],
      parameters: admin_api_params(),
      requestBody: request_body("Parameters", create_request(), required: true),
      responses: %{
        200 => Operation.response("Response", "application/json", domain()),
        400 => Operation.response("Bad Request", "application/json", ApiError),
        403 => Operation.response("Forbidden", "application/json", ApiError)
      }
    }
  end

  def update_operation do
    %Operation{
      tags: ["Domain management"],
      summary: "Modify existing domain",
      operationId: "AdminAPI.DomainController.update",
      security: [%{"oAuth" => ["admin:write"]}],
      parameters: [Operation.parameter(:id, :path, :string, "Domain ID")],
      requestBody: request_body("Parameters", update_request(), required: true),
      responses: %{
        200 => Operation.response("Response", "application/json", domain()),
        400 => Operation.response("Bad Request", "application/json", ApiError),
        403 => Operation.response("Forbidden", "application/json", ApiError)
      }
    }
  end

  def delete_operation do
    %Operation{
      tags: ["Domain management"],
      summary: "Delete domain",
      operationId: "AdminAPI.DomainController.delete",
      parameters: [Operation.parameter(:id, :path, :string, "Domain ID")],
      security: [%{"oAuth" => ["admin:write"]}],
      responses: %{
        200 => empty_object_response(),
        404 => Operation.response("Not Found", "application/json", ApiError),
        403 => Operation.response("Forbidden", "application/json", ApiError)
      }
    }
  end

  defp create_request do
    %Schema{
      type: :object,
      required: [:domain],
      properties: %{
        domain: %Schema{type: :string},
        public: %Schema{type: :boolean, nullable: true}
      }
    }
  end

  defp update_request do
    %Schema{
      type: :object,
      properties: %{
        public: %Schema{type: :boolean, nullable: true}
      }
    }
  end

  defp domain do
    %Schema{
      type: :object,
      properties: %{
        id: %Schema{type: :integer},
        domain: %Schema{type: :string},
        public: %Schema{type: :boolean},
        resolves: %Schema{type: :boolean},
        last_checked_at: %Schema{type: :string, format: "date-time", nullable: true}
      }
    }
  end
end
