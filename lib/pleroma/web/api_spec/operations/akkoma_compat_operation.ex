# Pleroma: A lightweight social networking server
# Copyright © 2017-2024 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.ApiSpec.AkkomaCompatOperation do
  alias OpenApiSpex.Operation
  alias OpenApiSpex.Schema
  alias Pleroma.Web.ApiSpec.Schemas.FlakeID

  def open_api_operation(action) do
    operation = String.to_existing_atom("#{action}_operation")
    apply(__MODULE__, operation, [])
  end

  # Adapted from https://akkoma.dev/AkkomaGang/akkoma/src/branch/develop/lib/pleroma/web/api_spec/operations/translate_operation.ex
  def translation_languages_operation do
    %Operation{
      tags: ["Akkoma compatibility routes"],
      summary: "Get translation languages",
      description: "Retreieve a list of supported source and target language",
      operationId: "AkkomaCompatController.translation_languages",
      responses: %{
        200 =>
          Operation.response(
            "Translation languages",
            "application/json",
            source_dest_languages_schema()
          )
      }
    }
  end

  defp source_dest_languages_schema do
    %Schema{
      type: :object,
      required: [:source, :target],
      properties: %{
        source: languages_schema(),
        target: languages_schema()
      }
    }
  end

  defp languages_schema do
    %Schema{
      type: :array,
      items: %Schema{
        type: :object,
        properties: %{
          code: %Schema{type: :string},
          name: %Schema{type: :string}
        }
      }
    }
  end

  def translate_operation do
    %Operation{
      tags: ["Akkoma compatibility routes"],
      summary: "Translate status",
      description: "Translate status with an external API",
      operationId: "AkkomaCompatController.translate",
      security: [%{"oAuth" => ["read:statuses"]}],
      parameters: [
        Operation.parameter(:id, :path, FlakeID.schema(), "Status ID",
          example: "9umDrYheeY451cQnEe",
          required: true
        ),
        Operation.parameter(:language, :path, :string, "Target language code", example: "en"),
        Operation.parameter(:from, :query, :string, "Source language code (unused)",
          example: "en"
        )
      ],
      responses: %{
        200 =>
          Operation.response(
            "Translated status",
            "application/json",
            %Schema{
              type: :object,
              required: [:detected_language, :text],
              properties: %{
                detected_language: %Schema{type: :string},
                text: %Schema{type: :string}
              }
            }
          )
      }
    }
  end
end
