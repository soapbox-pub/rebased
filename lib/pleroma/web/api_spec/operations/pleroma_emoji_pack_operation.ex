# Pleroma: A lightweight social networking server
# Copyright © 2017-2022 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.ApiSpec.PleromaEmojiPackOperation do
  alias OpenApiSpex.Operation
  alias OpenApiSpex.Schema
  alias Pleroma.Web.ApiSpec.Schemas.ApiError

  import Pleroma.Web.ApiSpec.Helpers

  def open_api_operation(action) do
    operation = String.to_existing_atom("#{action}_operation")
    apply(__MODULE__, operation, [])
  end

  def remote_operation do
    %Operation{
      tags: ["Emoji pack administration"],
      summary: "Make request to another instance for emoji packs list",
      security: [%{"oAuth" => ["admin:write"]}],
      parameters: [
        url_param(),
        Operation.parameter(
          :page,
          :query,
          %Schema{type: :integer, default: 1},
          "Page"
        ),
        Operation.parameter(
          :page_size,
          :query,
          %Schema{type: :integer, default: 30},
          "Number of emoji to return"
        )
      ],
      operationId: "PleromaAPI.EmojiPackController.remote",
      responses: %{
        200 => emoji_packs_response(),
        500 => Operation.response("Error", "application/json", ApiError)
      }
    }
  end

  def index_operation do
    %Operation{
      tags: ["Emoji packs"],
      summary: "Lists local custom emoji packs",
      operationId: "PleromaAPI.EmojiPackController.index",
      parameters: [
        Operation.parameter(
          :page,
          :query,
          %Schema{type: :integer, default: 1},
          "Page"
        ),
        Operation.parameter(
          :page_size,
          :query,
          %Schema{type: :integer, default: 50},
          "Number of emoji packs to return"
        )
      ],
      responses: %{
        200 => emoji_packs_response()
      }
    }
  end

  def show_operation do
    %Operation{
      tags: ["Emoji packs"],
      summary: "Show emoji pack",
      operationId: "PleromaAPI.EmojiPackController.show",
      parameters: [
        name_param(),
        Operation.parameter(
          :page,
          :query,
          %Schema{type: :integer, default: 1},
          "Page"
        ),
        Operation.parameter(
          :page_size,
          :query,
          %Schema{type: :integer, default: 30},
          "Number of emoji to return"
        )
      ],
      responses: %{
        200 => Operation.response("Emoji Pack", "application/json", emoji_pack()),
        400 => Operation.response("Bad Request", "application/json", ApiError),
        404 => Operation.response("Not Found", "application/json", ApiError)
      }
    }
  end

  def archive_operation do
    %Operation{
      tags: ["Emoji packs"],
      summary: "Requests a local pack archive from the instance",
      operationId: "PleromaAPI.EmojiPackController.archive",
      parameters: [name_param()],
      responses: %{
        200 =>
          Operation.response("Archive file", "application/octet-stream", %Schema{
            type: :string,
            format: :binary
          }),
        403 => Operation.response("Forbidden", "application/json", ApiError),
        404 => Operation.response("Not Found", "application/json", ApiError)
      }
    }
  end

  def download_operation do
    %Operation{
      tags: ["Emoji pack administration"],
      summary: "Download pack from another instance",
      operationId: "PleromaAPI.EmojiPackController.download",
      security: [%{"oAuth" => ["admin:write"]}],
      requestBody: request_body("Parameters", download_request(), required: true),
      responses: %{
        200 => ok_response(),
        500 => Operation.response("Error", "application/json", ApiError)
      }
    }
  end

  defp download_request do
    %Schema{
      type: :object,
      required: [:url, :name],
      properties: %{
        url: %Schema{
          type: :string,
          format: :uri,
          description: "URL of the instance to download from"
        },
        name: %Schema{type: :string, format: :uri, description: "Pack Name"},
        as: %Schema{type: :string, format: :uri, description: "Save as"}
      }
    }
  end

  def create_operation do
    %Operation{
      tags: ["Emoji pack administration"],
      summary: "Create an empty pack",
      operationId: "PleromaAPI.EmojiPackController.create",
      security: [%{"oAuth" => ["admin:write"]}],
      parameters: [name_param()],
      responses: %{
        200 => ok_response(),
        400 => Operation.response("Not Found", "application/json", ApiError),
        409 => Operation.response("Conflict", "application/json", ApiError),
        500 => Operation.response("Error", "application/json", ApiError)
      }
    }
  end

  def delete_operation do
    %Operation{
      tags: ["Emoji pack administration"],
      summary: "Delete a custom emoji pack",
      operationId: "PleromaAPI.EmojiPackController.delete",
      security: [%{"oAuth" => ["admin:write"]}],
      parameters: [name_param()],
      responses: %{
        200 => ok_response(),
        400 => Operation.response("Bad Request", "application/json", ApiError),
        404 => Operation.response("Not Found", "application/json", ApiError),
        500 => Operation.response("Error", "application/json", ApiError)
      }
    }
  end

  def update_operation do
    %Operation{
      tags: ["Emoji pack administration"],
      summary: "Updates (replaces) pack metadata",
      operationId: "PleromaAPI.EmojiPackController.update",
      security: [%{"oAuth" => ["admin:write"]}],
      requestBody: request_body("Parameters", update_request(), required: true),
      parameters: [name_param()],
      responses: %{
        200 => Operation.response("Metadata", "application/json", metadata()),
        400 => Operation.response("Bad Request", "application/json", ApiError),
        500 => Operation.response("Error", "application/json", ApiError)
      }
    }
  end

  def import_from_filesystem_operation do
    %Operation{
      tags: ["Emoji pack administration"],
      summary: "Imports packs from filesystem",
      operationId: "PleromaAPI.EmojiPackController.import",
      security: [%{"oAuth" => ["admin:write"]}],
      responses: %{
        200 =>
          Operation.response("Array of imported pack names", "application/json", %Schema{
            type: :array,
            items: %Schema{type: :string}
          })
      }
    }
  end

  defp name_param do
    Operation.parameter(:name, :query, :string, "Pack Name", example: "cofe", required: true)
  end

  defp url_param do
    Operation.parameter(
      :url,
      :query,
      %Schema{type: :string, format: :uri},
      "URL of the instance",
      required: true
    )
  end

  defp ok_response do
    Operation.response("Ok", "application/json", %Schema{type: :string, example: "ok"})
  end

  defp emoji_packs_response do
    Operation.response(
      "Object with pack names as keys and pack contents as values",
      "application/json",
      %Schema{
        type: :object,
        additionalProperties: emoji_pack(),
        example: %{
          "emojos" => emoji_pack().example
        }
      }
    )
  end

  defp emoji_pack do
    %Schema{
      title: "EmojiPack",
      type: :object,
      properties: %{
        files: files_object(),
        pack: %Schema{
          type: :object,
          properties: %{
            license: %Schema{type: :string},
            homepage: %Schema{type: :string, format: :uri},
            description: %Schema{type: :string},
            "can-download": %Schema{type: :boolean},
            "share-files": %Schema{type: :boolean},
            "download-sha256": %Schema{type: :string}
          }
        }
      },
      example: %{
        "files" => %{"emacs" => "emacs.png", "guix" => "guix.png"},
        "pack" => %{
          "license" => "Test license",
          "homepage" => "https://pleroma.social",
          "description" => "Test description",
          "can-download" => true,
          "share-files" => true,
          "download-sha256" => "57482F30674FD3DE821FF48C81C00DA4D4AF1F300209253684ABA7075E5FC238"
        }
      }
    }
  end

  defp files_object do
    %Schema{
      type: :object,
      additionalProperties: %Schema{type: :string},
      description: "Object with emoji names as keys and filenames as values"
    }
  end

  defp update_request do
    %Schema{
      type: :object,
      properties: %{
        metadata: %Schema{
          type: :object,
          description: "Metadata to replace the old one",
          properties: %{
            license: %Schema{type: :string},
            homepage: %Schema{type: :string, format: :uri},
            description: %Schema{type: :string},
            "fallback-src": %Schema{
              type: :string,
              format: :uri,
              description: "Fallback url to download pack from"
            },
            "fallback-src-sha256": %Schema{
              type: :string,
              description: "SHA256 encoded for fallback pack archive"
            },
            "share-files": %Schema{type: :boolean, description: "Is pack allowed for sharing?"}
          }
        }
      }
    }
  end

  defp metadata do
    %Schema{
      type: :object,
      properties: %{
        license: %Schema{type: :string},
        homepage: %Schema{type: :string, format: :uri},
        description: %Schema{type: :string},
        "fallback-src": %Schema{
          type: :string,
          format: :uri,
          description: "Fallback url to download pack from"
        },
        "fallback-src-sha256": %Schema{
          type: :string,
          description: "SHA256 encoded for fallback pack archive"
        },
        "share-files": %Schema{type: :boolean, description: "Is pack allowed for sharing?"}
      }
    }
  end
end
