# Pleroma: A lightweight social networking server
# Copyright © 2017-2022 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.ApiSpec.MediaOperation do
  alias OpenApiSpex.Operation
  alias OpenApiSpex.Schema
  alias Pleroma.Web.ApiSpec.Helpers
  alias Pleroma.Web.ApiSpec.Schemas.ApiError
  alias Pleroma.Web.ApiSpec.Schemas.Attachment

  def open_api_operation(action) do
    operation = String.to_existing_atom("#{action}_operation")
    apply(__MODULE__, operation, [])
  end

  def create_operation do
    %Operation{
      tags: ["Media attachments"],
      summary: "Upload media as attachment",
      description: "Creates an attachment to be used with a new status.",
      operationId: "MediaController.create",
      security: [%{"oAuth" => ["write:media"]}],
      requestBody: Helpers.request_body("Parameters", create_request()),
      responses: %{
        200 => Operation.response("Media", "application/json", Attachment),
        400 => Operation.response("Media", "application/json", ApiError),
        401 => Operation.response("Media", "application/json", ApiError),
        422 => Operation.response("Media", "application/json", ApiError)
      }
    }
  end

  defp create_request do
    %Schema{
      title: "MediaCreateRequest",
      description: "POST body for creating an attachment",
      type: :object,
      required: [:file],
      properties: %{
        file: %Schema{
          type: :string,
          format: :binary,
          description: "The file to be attached, using multipart form data."
        },
        description: %Schema{
          type: :string,
          description: "A plain-text description of the media, for accessibility purposes."
        },
        focus: %Schema{
          type: :string,
          description: "Two floating points (x,y), comma-delimited, ranging from -1.0 to 1.0."
        }
      }
    }
  end

  def update_operation do
    %Operation{
      tags: ["Media attachments"],
      summary: "Update attachment",
      description: "Creates an attachment to be used with a new status.",
      operationId: "MediaController.update",
      security: [%{"oAuth" => ["write:media"]}],
      parameters: [id_param()],
      requestBody: Helpers.request_body("Parameters", update_request()),
      responses: %{
        200 => Operation.response("Media", "application/json", Attachment),
        400 => Operation.response("Media", "application/json", ApiError),
        401 => Operation.response("Media", "application/json", ApiError),
        422 => Operation.response("Media", "application/json", ApiError)
      }
    }
  end

  defp update_request do
    %Schema{
      title: "MediaUpdateRequest",
      description: "POST body for updating an attachment",
      type: :object,
      properties: %{
        file: %Schema{
          type: :string,
          format: :binary,
          description: "The file to be attached, using multipart form data."
        },
        description: %Schema{
          type: :string,
          description: "A plain-text description of the media, for accessibility purposes."
        },
        focus: %Schema{
          type: :string,
          description: "Two floating points (x,y), comma-delimited, ranging from -1.0 to 1.0."
        }
      }
    }
  end

  def show_operation do
    %Operation{
      tags: ["Media attachments"],
      summary: "Attachment",
      operationId: "MediaController.show",
      parameters: [id_param()],
      security: [%{"oAuth" => ["read:media"]}],
      responses: %{
        200 => Operation.response("Media", "application/json", Attachment),
        401 => Operation.response("Media", "application/json", ApiError),
        403 => Operation.response("Media", "application/json", ApiError),
        422 => Operation.response("Media", "application/json", ApiError)
      }
    }
  end

  def create2_operation do
    %Operation{
      tags: ["Media attachments"],
      summary: "Upload media as attachment (v2)",
      description: "Creates an attachment to be used with a new status.",
      operationId: "MediaController.create2",
      security: [%{"oAuth" => ["write:media"]}],
      requestBody: Helpers.request_body("Parameters", create_request()),
      responses: %{
        202 => Operation.response("Media", "application/json", Attachment),
        400 => Operation.response("Media", "application/json", ApiError),
        422 => Operation.response("Media", "application/json", ApiError),
        500 => Operation.response("Media", "application/json", ApiError)
      }
    }
  end

  defp id_param do
    Operation.parameter(:id, :path, :string, "The ID of the Attachment entity")
  end
end
