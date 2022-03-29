# Pleroma: A lightweight social networking server
# Copyright © 2017-2022 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.ApiSpec.PleromaEmojiFileOperation do
  alias OpenApiSpex.Operation
  alias OpenApiSpex.Schema
  alias Pleroma.Web.ApiSpec.Schemas.ApiError

  import Pleroma.Web.ApiSpec.Helpers

  def open_api_operation(action) do
    operation = String.to_existing_atom("#{action}_operation")
    apply(__MODULE__, operation, [])
  end

  def create_operation do
    %Operation{
      tags: ["Emoji pack administration"],
      summary: "Add new file to the pack",
      operationId: "PleromaAPI.EmojiPackController.add_file",
      security: [%{"oAuth" => ["admin:write"]}],
      requestBody: request_body("Parameters", create_request(), required: true),
      parameters: [name_param()],
      responses: %{
        200 => Operation.response("Files Object", "application/json", files_object()),
        422 => Operation.response("Unprocessable Entity", "application/json", ApiError),
        404 => Operation.response("Not Found", "application/json", ApiError),
        400 => Operation.response("Bad Request", "application/json", ApiError),
        409 => Operation.response("Conflict", "application/json", ApiError),
        500 => Operation.response("Error", "application/json", ApiError)
      }
    }
  end

  defp create_request do
    %Schema{
      type: :object,
      required: [:file],
      properties: %{
        file: %Schema{
          description:
            "File needs to be uploaded with the multipart request or link to remote file",
          anyOf: [
            %Schema{type: :string, format: :binary},
            %Schema{type: :string, format: :uri}
          ]
        },
        shortcode: %Schema{
          type: :string,
          description:
            "Shortcode for new emoji, must be unique for all emoji. If not sended, shortcode will be taken from original filename."
        },
        filename: %Schema{
          type: :string,
          description:
            "New emoji file name. If not specified will be taken from original filename."
        }
      }
    }
  end

  def update_operation do
    %Operation{
      tags: ["Emoji pack administration"],
      summary: "Add new file to the pack",
      operationId: "PleromaAPI.EmojiPackController.update_file",
      security: [%{"oAuth" => ["admin:write"]}],
      requestBody: request_body("Parameters", update_request(), required: true),
      parameters: [name_param()],
      responses: %{
        200 => Operation.response("Files Object", "application/json", files_object()),
        404 => Operation.response("Not Found", "application/json", ApiError),
        400 => Operation.response("Bad Request", "application/json", ApiError),
        409 => Operation.response("Conflict", "application/json", ApiError),
        422 => Operation.response("Unprocessable Entity", "application/json", ApiError)
      }
    }
  end

  defp update_request do
    %Schema{
      type: :object,
      required: [:shortcode, :new_shortcode, :new_filename],
      properties: %{
        shortcode: %Schema{
          type: :string,
          description: "Emoji file shortcode"
        },
        new_shortcode: %Schema{
          type: :string,
          description: "New emoji file shortcode"
        },
        new_filename: %Schema{
          type: :string,
          description: "New filename for emoji file"
        },
        force: %Schema{
          type: :boolean,
          description: "With true value to overwrite existing emoji with new shortcode",
          default: false
        }
      }
    }
  end

  def delete_operation do
    %Operation{
      tags: ["Emoji pack administration"],
      summary: "Delete emoji file from pack",
      operationId: "PleromaAPI.EmojiPackController.delete_file",
      security: [%{"oAuth" => ["admin:write"]}],
      parameters: [
        name_param(),
        Operation.parameter(:shortcode, :query, :string, "File shortcode",
          example: "cofe",
          required: true
        )
      ],
      responses: %{
        200 => Operation.response("Files Object", "application/json", files_object()),
        400 => Operation.response("Bad Request", "application/json", ApiError),
        404 => Operation.response("Not Found", "application/json", ApiError),
        422 => Operation.response("Unprocessable Entity", "application/json", ApiError)
      }
    }
  end

  defp name_param do
    Operation.parameter(:name, :query, :string, "Pack Name", example: "cofe", required: true)
  end

  defp files_object do
    %Schema{
      type: :object,
      additionalProperties: %Schema{type: :string},
      description: "Object with emoji names as keys and filenames as values"
    }
  end
end
