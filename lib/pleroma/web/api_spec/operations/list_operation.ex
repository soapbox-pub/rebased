# Pleroma: A lightweight social networking server
# Copyright © 2017-2022 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.ApiSpec.ListOperation do
  alias OpenApiSpex.Operation
  alias OpenApiSpex.Schema
  alias Pleroma.Web.ApiSpec.Schemas.Account
  alias Pleroma.Web.ApiSpec.Schemas.ApiError
  alias Pleroma.Web.ApiSpec.Schemas.FlakeID
  alias Pleroma.Web.ApiSpec.Schemas.List

  import Pleroma.Web.ApiSpec.Helpers

  def open_api_operation(action) do
    operation = String.to_existing_atom("#{action}_operation")
    apply(__MODULE__, operation, [])
  end

  def index_operation do
    %Operation{
      tags: ["Lists"],
      summary: "Retrieve a list of lists",
      description: "Fetch all lists that the user owns",
      security: [%{"oAuth" => ["read:lists"]}],
      operationId: "ListController.index",
      responses: %{
        200 => Operation.response("Array of List", "application/json", array_of_lists())
      }
    }
  end

  def create_operation do
    %Operation{
      tags: ["Lists"],
      summary: "Create a list",
      description: "Fetch the list with the given ID. Used for verifying the title of a list.",
      operationId: "ListController.create",
      requestBody: create_update_request(),
      security: [%{"oAuth" => ["write:lists"]}],
      responses: %{
        200 => Operation.response("List", "application/json", List),
        400 => Operation.response("Error", "application/json", ApiError),
        404 => Operation.response("Error", "application/json", ApiError)
      }
    }
  end

  def show_operation do
    %Operation{
      tags: ["Lists"],
      summary: "Retrieve a list",
      description: "Fetch the list with the given ID. Used for verifying the title of a list.",
      operationId: "ListController.show",
      parameters: [id_param()],
      security: [%{"oAuth" => ["read:lists"]}],
      responses: %{
        200 => Operation.response("List", "application/json", List),
        404 => Operation.response("Error", "application/json", ApiError)
      }
    }
  end

  def update_operation do
    %Operation{
      tags: ["Lists"],
      summary: "Update a list",
      description: "Change the title of a list",
      operationId: "ListController.update",
      parameters: [id_param()],
      requestBody: create_update_request(),
      security: [%{"oAuth" => ["write:lists"]}],
      responses: %{
        200 => Operation.response("List", "application/json", List),
        422 => Operation.response("Error", "application/json", ApiError)
      }
    }
  end

  def delete_operation do
    %Operation{
      tags: ["Lists"],
      summary: "Delete a list",
      operationId: "ListController.delete",
      parameters: [id_param()],
      security: [%{"oAuth" => ["write:lists"]}],
      responses: %{
        200 => Operation.response("Empty object", "application/json", %Schema{type: :object})
      }
    }
  end

  def list_accounts_operation do
    %Operation{
      tags: ["Lists"],
      summary: "Retrieve accounts in list",
      operationId: "ListController.list_accounts",
      parameters: [id_param()],
      security: [%{"oAuth" => ["read:lists"]}],
      responses: %{
        200 =>
          Operation.response("Array of Account", "application/json", %Schema{
            type: :array,
            items: Account
          })
      }
    }
  end

  def add_to_list_operation do
    %Operation{
      tags: ["Lists"],
      summary: "Add accounts to list",
      description: "Add accounts to the given list.",
      operationId: "ListController.add_to_list",
      parameters: [id_param()],
      requestBody: add_remove_accounts_request(true),
      security: [%{"oAuth" => ["write:lists"]}],
      responses: %{
        200 => Operation.response("Empty object", "application/json", %Schema{type: :object})
      }
    }
  end

  def remove_from_list_operation do
    %Operation{
      tags: ["Lists"],
      summary: "Remove accounts from list",
      operationId: "ListController.remove_from_list",
      parameters: [
        id_param(),
        Operation.parameter(
          :account_ids,
          :query,
          %Schema{type: :array, items: %Schema{type: :string}},
          "Array of account IDs"
        )
      ],
      requestBody: add_remove_accounts_request(false),
      security: [%{"oAuth" => ["write:lists"]}],
      responses: %{
        200 => Operation.response("Empty object", "application/json", %Schema{type: :object})
      }
    }
  end

  defp array_of_lists do
    %Schema{
      title: "ArrayOfLists",
      description: "Response schema for lists",
      type: :array,
      items: List,
      example: [
        %{"id" => "123", "title" => "my list"},
        %{"id" => "1337", "title" => "another list"}
      ]
    }
  end

  defp id_param do
    Operation.parameter(:id, :path, :string, "List ID",
      example: "123",
      required: true
    )
  end

  defp create_update_request do
    request_body(
      "Parameters",
      %Schema{
        description: "POST body for creating or updating a List",
        type: :object,
        properties: %{
          title: %Schema{type: :string, description: "List title"}
        },
        required: [:title]
      },
      required: true
    )
  end

  defp add_remove_accounts_request(required) when is_boolean(required) do
    request_body(
      "Parameters",
      %Schema{
        description: "POST body for adding/removing accounts to/from a List",
        type: :object,
        properties: %{
          account_ids: %Schema{type: :array, description: "Array of account IDs", items: FlakeID}
        }
      },
      required: required
    )
  end
end
