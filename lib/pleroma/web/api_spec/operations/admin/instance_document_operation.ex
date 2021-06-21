# Pleroma: A lightweight social networking server
# Copyright © 2017-2021 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.ApiSpec.Admin.InstanceDocumentOperation do
  alias OpenApiSpex.Operation
  alias OpenApiSpex.Schema
  alias Pleroma.Web.ApiSpec.Helpers
  alias Pleroma.Web.ApiSpec.Schemas.ApiError

  def open_api_operation(action) do
    operation = String.to_existing_atom("#{action}_operation")
    apply(__MODULE__, operation, [])
  end

  def show_operation do
    %Operation{
      tags: ["Instance documents"],
      summary: "Retrieve an instance document",
      operationId: "AdminAPI.InstanceDocumentController.show",
      security: [%{"oAuth" => ["admin:read"]}],
      parameters: [
        Operation.parameter(:name, :path, %Schema{type: :string}, "The document name",
          required: true
        )
        | Helpers.admin_api_params()
      ],
      responses: %{
        200 => document_content(),
        400 => Operation.response("Bad Request", "application/json", ApiError),
        403 => Operation.response("Forbidden", "application/json", ApiError),
        404 => Operation.response("Not Found", "application/json", ApiError)
      }
    }
  end

  def update_operation do
    %Operation{
      tags: ["Instance documents"],
      summary: "Update an instance document",
      operationId: "AdminAPI.InstanceDocumentController.update",
      security: [%{"oAuth" => ["admin:write"]}],
      requestBody: Helpers.request_body("Parameters", update_request()),
      parameters: [
        Operation.parameter(:name, :path, %Schema{type: :string}, "The document name",
          required: true
        )
        | Helpers.admin_api_params()
      ],
      responses: %{
        200 => Operation.response("InstanceDocument", "application/json", instance_document()),
        400 => Operation.response("Bad Request", "application/json", ApiError),
        403 => Operation.response("Forbidden", "application/json", ApiError),
        404 => Operation.response("Not Found", "application/json", ApiError)
      }
    }
  end

  defp update_request do
    %Schema{
      title: "UpdateRequest",
      description: "POST body for uploading the file",
      type: :object,
      required: [:file],
      properties: %{
        file: %Schema{
          type: :string,
          format: :binary,
          description: "The file to be uploaded, using multipart form data."
        }
      }
    }
  end

  def delete_operation do
    %Operation{
      tags: ["Instance documents"],
      summary: "Delete an instance document",
      operationId: "AdminAPI.InstanceDocumentController.delete",
      security: [%{"oAuth" => ["admin:write"]}],
      parameters: [
        Operation.parameter(:name, :path, %Schema{type: :string}, "The document name",
          required: true
        )
        | Helpers.admin_api_params()
      ],
      responses: %{
        200 => Operation.response("InstanceDocument", "application/json", instance_document()),
        400 => Operation.response("Bad Request", "application/json", ApiError),
        403 => Operation.response("Forbidden", "application/json", ApiError),
        404 => Operation.response("Not Found", "application/json", ApiError)
      }
    }
  end

  defp instance_document do
    %Schema{
      title: "InstanceDocument",
      type: :object,
      properties: %{
        url: %Schema{type: :string}
      },
      example: %{
        "url" => "https://example.com/static/terms-of-service.html"
      }
    }
  end

  defp document_content do
    Operation.response("InstanceDocumentContent", "text/html", %Schema{
      type: :string,
      example: "<h1>Instance panel</h1>"
    })
  end
end
