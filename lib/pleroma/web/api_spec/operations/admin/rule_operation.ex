# Pleroma: A lightweight social networking server
# Copyright © 2017-2022 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.ApiSpec.Admin.RuleOperation do
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
      tags: ["Instance rule managment"],
      summary: "Retrieve list of instance rules",
      operationId: "AdminAPI.RuleController.index",
      security: [%{"oAuth" => ["admin:read"]}],
      responses: %{
        200 =>
          Operation.response("Response", "application/json", %Schema{
            type: :array,
            items: rule()
          }),
        403 => Operation.response("Forbidden", "application/json", ApiError)
      }
    }
  end

  def create_operation do
    %Operation{
      tags: ["Instance rule managment"],
      summary: "Create new rule",
      operationId: "AdminAPI.RuleController.create",
      security: [%{"oAuth" => ["admin:write"]}],
      parameters: admin_api_params(),
      requestBody: request_body("Parameters", create_request(), required: true),
      responses: %{
        200 => Operation.response("Response", "application/json", rule()),
        400 => Operation.response("Bad Request", "application/json", ApiError),
        403 => Operation.response("Forbidden", "application/json", ApiError)
      }
    }
  end

  def update_operation do
    %Operation{
      tags: ["Instance rule managment"],
      summary: "Modify existing rule",
      operationId: "AdminAPI.RuleController.update",
      security: [%{"oAuth" => ["admin:write"]}],
      parameters: [Operation.parameter(:id, :path, :string, "Rule ID")],
      requestBody: request_body("Parameters", update_request(), required: true),
      responses: %{
        200 => Operation.response("Response", "application/json", rule()),
        400 => Operation.response("Bad Request", "application/json", ApiError),
        403 => Operation.response("Forbidden", "application/json", ApiError)
      }
    }
  end

  def delete_operation do
    %Operation{
      tags: ["Instance rule managment"],
      summary: "Delete rule",
      operationId: "AdminAPI.RuleController.delete",
      parameters: [Operation.parameter(:id, :path, :string, "Rule ID")],
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
      required: [:text],
      properties: %{
        priority: %Schema{type: :integer},
        text: %Schema{type: :string}
      }
    }
  end

  defp update_request do
    %Schema{
      type: :object,
      properties: %{
        priority: %Schema{type: :integer},
        text: %Schema{type: :string}
      }
    }
  end

  defp rule do
    %Schema{
      type: :object,
      properties: %{
        id: %Schema{type: :integer},
        priority: %Schema{type: :integer},
        text: %Schema{type: :string},
        created_at: %Schema{type: :string, format: :"date-time"}
      }
    }
  end
end
