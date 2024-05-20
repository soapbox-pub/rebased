# Pleroma: A lightweight social networking server
# Copyright © 2017-2024 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.ApiSpec.PleromaBookmarkFolderOperation do
  alias OpenApiSpex.Operation
  alias OpenApiSpex.Schema
  alias Pleroma.Web.ApiSpec.Schemas.ApiError
  alias Pleroma.Web.ApiSpec.Schemas.BookmarkFolder
  alias Pleroma.Web.ApiSpec.Schemas.FlakeID

  import Pleroma.Web.ApiSpec.Helpers

  @spec open_api_operation(any()) :: any()
  def open_api_operation(action) do
    operation = String.to_existing_atom("#{action}_operation")
    apply(__MODULE__, operation, [])
  end

  def index_operation do
    %Operation{
      tags: ["Bookmark folders"],
      summary: "All bookmark folders",
      security: [%{"oAuth" => ["read:bookmarks"]}],
      operationId: "PleromaAPI.BookmarkFolderController.index",
      responses: %{
        200 =>
          Operation.response("Array of Bookmark Folders", "application/json", %Schema{
            type: :array,
            items: BookmarkFolder
          })
      }
    }
  end

  def create_operation do
    %Operation{
      tags: ["Bookmark folders"],
      summary: "Create a bookmark folder",
      security: [%{"oAuth" => ["write:bookmarks"]}],
      operationId: "PleromaAPI.BookmarkFolderController.create",
      requestBody: request_body("Parameters", create_request(), required: true),
      responses: %{
        200 => Operation.response("Bookmark Folder", "application/json", BookmarkFolder),
        422 => Operation.response("Error", "application/json", ApiError)
      }
    }
  end

  def update_operation do
    %Operation{
      tags: ["Bookmark folders"],
      summary: "Update a bookmark folder",
      security: [%{"oAuth" => ["write:bookmarks"]}],
      operationId: "PleromaAPI.BookmarkFolderController.update",
      parameters: [id_param()],
      requestBody: request_body("Parameters", update_request(), required: true),
      responses: %{
        200 => Operation.response("Bookmark Folder", "application/json", BookmarkFolder),
        403 => Operation.response("Forbidden", "application/json", ApiError),
        404 => Operation.response("Not Found", "application/json", ApiError),
        422 => Operation.response("Error", "application/json", ApiError)
      }
    }
  end

  def delete_operation do
    %Operation{
      tags: ["Bookmark folders"],
      summary: "Delete a bookmark folder",
      security: [%{"oAuth" => ["write:bookmarks"]}],
      operationId: "PleromaAPI.BookmarkFolderController.delete",
      parameters: [id_param()],
      responses: %{
        200 => Operation.response("Bookmark Folder", "application/json", BookmarkFolder),
        403 => Operation.response("Forbidden", "application/json", ApiError),
        404 => Operation.response("Not Found", "application/json", ApiError)
      }
    }
  end

  defp create_request do
    %Schema{
      title: "BookmarkFolderCreateRequest",
      type: :object,
      properties: %{
        name: %Schema{
          type: :string,
          description: "Folder name"
        },
        emoji: %Schema{
          type: :string,
          nullable: true,
          description: "Folder emoji"
        }
      }
    }
  end

  defp update_request do
    %Schema{
      title: "BookmarkFolderUpdateRequest",
      type: :object,
      properties: %{
        name: %Schema{
          type: :string,
          nullable: true,
          description: "Folder name"
        },
        emoji: %Schema{
          type: :string,
          nullable: true,
          description: "Folder emoji"
        }
      }
    }
  end

  def id_param do
    Operation.parameter(:id, :path, FlakeID.schema(), "Bookmark Folder ID",
      example: "9umDrYheeY451cQnEe",
      required: true
    )
  end
end
