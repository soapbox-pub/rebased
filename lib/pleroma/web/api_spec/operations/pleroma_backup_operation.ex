# Pleroma: A lightweight social networking server
# Copyright © 2017-2020 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.ApiSpec.PleromaBackupOperation do
  alias OpenApiSpex.Operation
  alias OpenApiSpex.Schema
  alias Pleroma.Web.ApiSpec.Schemas.ApiError

  def open_api_operation(action) do
    operation = String.to_existing_atom("#{action}_operation")
    apply(__MODULE__, operation, [])
  end

  def index_operation do
    %Operation{
      tags: ["Backups"],
      summary: "List backups",
      security: [%{"oAuth" => ["read:account"]}],
      operationId: "PleromaAPI.BackupController.index",
      responses: %{
        200 =>
          Operation.response(
            "An array of backups",
            "application/json",
            %Schema{
              type: :array,
              items: backup()
            }
          ),
        400 => Operation.response("Bad Request", "application/json", ApiError)
      }
    }
  end

  def create_operation do
    %Operation{
      tags: ["Backups"],
      summary: "Create a backup",
      security: [%{"oAuth" => ["read:account"]}],
      operationId: "PleromaAPI.BackupController.create",
      responses: %{
        200 =>
          Operation.response(
            "An array of backups",
            "application/json",
            %Schema{
              type: :array,
              items: backup()
            }
          ),
        400 => Operation.response("Bad Request", "application/json", ApiError)
      }
    }
  end

  defp backup do
    %Schema{
      title: "Backup",
      description: "Response schema for a backup",
      type: :object,
      properties: %{
        inserted_at: %Schema{type: :string, format: :"date-time"},
        content_type: %Schema{type: :string},
        file_name: %Schema{type: :string},
        file_size: %Schema{type: :integer},
        processed: %Schema{type: :boolean}
      },
      example: %{
        "content_type" => "application/zip",
        "file_name" =>
          "archive-cofe-20200908T195819-1lWrJyJqpsj8-KuHFr7N03lfsYYa5nf2NL-7A9-ddFU.zip",
        "file_size" => 1024,
        "inserted_at" => "2020-09-08T19:58:20",
        "processed" => true
      }
    }
  end
end
