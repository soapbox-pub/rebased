# Pleroma: A lightweight social networking server
# Copyright © 2017-2021 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.ApiSpec.PleromaMascotOperation do
  alias OpenApiSpex.Operation
  alias OpenApiSpex.Schema
  alias Pleroma.Web.ApiSpec.Schemas.ApiError

  import Pleroma.Web.ApiSpec.Helpers

  def open_api_operation(action) do
    operation = String.to_existing_atom("#{action}_operation")
    apply(__MODULE__, operation, [])
  end

  def show_operation do
    %Operation{
      tags: ["Mascot"],
      summary: "Retrieve mascot",
      security: [%{"oAuth" => ["read:accounts"]}],
      operationId: "PleromaAPI.MascotController.show",
      responses: %{
        200 => Operation.response("Mascot", "application/json", mascot())
      }
    }
  end

  def update_operation do
    %Operation{
      tags: ["Mascot"],
      summary: "Set or clear mascot",
      description:
        "Behaves exactly the same as `POST /api/v1/upload`. Can only accept images - any attempt to upload non-image files will be met with `HTTP 415 Unsupported Media Type`.",
      operationId: "PleromaAPI.MascotController.update",
      requestBody:
        request_body(
          "Parameters",
          %Schema{
            type: :object,
            properties: %{
              file: %Schema{type: :string, format: :binary}
            }
          },
          required: true
        ),
      security: [%{"oAuth" => ["write:accounts"]}],
      responses: %{
        200 => Operation.response("Mascot", "application/json", mascot()),
        415 => Operation.response("Unsupported Media Type", "application/json", ApiError)
      }
    }
  end

  defp mascot do
    %Schema{
      type: :object,
      properties: %{
        id: %Schema{type: :string},
        url: %Schema{type: :string, format: :uri},
        type: %Schema{type: :string},
        pleroma: %Schema{
          type: :object,
          properties: %{
            mime_type: %Schema{type: :string}
          }
        }
      },
      example: %{
        "id" => "abcdefg",
        "url" => "https://pleroma.example.org/media/abcdefg.png",
        "type" => "image",
        "pleroma" => %{
          "mime_type" => "image/png"
        }
      }
    }
  end
end
