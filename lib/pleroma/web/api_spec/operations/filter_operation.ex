# Pleroma: A lightweight social networking server
# Copyright © 2017-2021 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.ApiSpec.FilterOperation do
  alias OpenApiSpex.Operation
  alias OpenApiSpex.Schema
  alias Pleroma.Web.ApiSpec.Helpers
  alias Pleroma.Web.ApiSpec.Schemas.ApiError
  alias Pleroma.Web.ApiSpec.Schemas.BooleanLike

  def open_api_operation(action) do
    operation = String.to_existing_atom("#{action}_operation")
    apply(__MODULE__, operation, [])
  end

  def index_operation do
    %Operation{
      tags: ["Filters"],
      summary: "All filters",
      operationId: "FilterController.index",
      security: [%{"oAuth" => ["read:filters"]}],
      responses: %{
        200 => Operation.response("Filters", "application/json", array_of_filters()),
        403 => Operation.response("Error", "application/json", ApiError)
      }
    }
  end

  def create_operation do
    %Operation{
      tags: ["Filters"],
      summary: "Create a filter",
      operationId: "FilterController.create",
      requestBody: Helpers.request_body("Parameters", create_request(), required: true),
      security: [%{"oAuth" => ["write:filters"]}],
      responses: %{
        200 => Operation.response("Filter", "application/json", filter()),
        403 => Operation.response("Error", "application/json", ApiError)
      }
    }
  end

  def show_operation do
    %Operation{
      tags: ["Filters"],
      summary: "Filter",
      parameters: [id_param()],
      operationId: "FilterController.show",
      security: [%{"oAuth" => ["read:filters"]}],
      responses: %{
        200 => Operation.response("Filter", "application/json", filter()),
        403 => Operation.response("Error", "application/json", ApiError),
        404 => Operation.response("Error", "application/json", ApiError)
      }
    }
  end

  def update_operation do
    %Operation{
      tags: ["Filters"],
      summary: "Update a filter",
      parameters: [id_param()],
      operationId: "FilterController.update",
      requestBody: Helpers.request_body("Parameters", update_request(), required: true),
      security: [%{"oAuth" => ["write:filters"]}],
      responses: %{
        200 => Operation.response("Filter", "application/json", filter()),
        403 => Operation.response("Error", "application/json", ApiError)
      }
    }
  end

  def delete_operation do
    %Operation{
      tags: ["Filters"],
      summary: "Remove a filter",
      parameters: [id_param()],
      operationId: "FilterController.delete",
      security: [%{"oAuth" => ["write:filters"]}],
      responses: %{
        200 =>
          Operation.response("Filter", "application/json", %Schema{
            type: :object,
            description: "Empty object"
          }),
        403 => Operation.response("Error", "application/json", ApiError)
      }
    }
  end

  defp id_param do
    Operation.parameter(:id, :path, :string, "Filter ID", example: "123", required: true)
  end

  defp filter do
    %Schema{
      title: "Filter",
      type: :object,
      properties: %{
        id: %Schema{type: :string},
        phrase: %Schema{type: :string, description: "The text to be filtered"},
        context: %Schema{
          type: :array,
          items: %Schema{type: :string, enum: ["home", "notifications", "public", "thread"]},
          description: "The contexts in which the filter should be applied."
        },
        expires_at: %Schema{
          type: :string,
          format: :"date-time",
          description:
            "When the filter should no longer be applied. String (ISO 8601 Datetime), or null if the filter does not expire.",
          nullable: true
        },
        irreversible: %Schema{
          type: :boolean,
          description:
            "Should matching entities in home and notifications be dropped by the server?"
        },
        whole_word: %Schema{
          type: :boolean,
          description: "Should the filter consider word boundaries?"
        }
      },
      example: %{
        "id" => "5580",
        "phrase" => "@twitter.com",
        "context" => [
          "home",
          "notifications",
          "public",
          "thread"
        ],
        "whole_word" => false,
        "expires_at" => nil,
        "irreversible" => true
      }
    }
  end

  defp array_of_filters do
    %Schema{
      title: "ArrayOfFilters",
      description: "Array of Filters",
      type: :array,
      items: filter(),
      example: [
        %{
          "id" => "5580",
          "phrase" => "@twitter.com",
          "context" => [
            "home",
            "notifications",
            "public",
            "thread"
          ],
          "whole_word" => false,
          "expires_at" => nil,
          "irreversible" => true
        },
        %{
          "id" => "6191",
          "phrase" => ":eurovision2019:",
          "context" => [
            "home"
          ],
          "whole_word" => true,
          "expires_at" => "2019-05-21T13:47:31.333Z",
          "irreversible" => false
        }
      ]
    }
  end

  defp create_request do
    %Schema{
      title: "FilterCreateRequest",
      allOf: [
        update_request(),
        %Schema{
          type: :object,
          properties: %{
            irreversible: %Schema{
              allOf: [BooleanLike],
              description:
                "Should the server irreversibly drop matching entities from home and notifications?",
              default: false
            }
          }
        }
      ],
      example: %{
        "phrase" => "knights",
        "context" => ["home"]
      }
    }
  end

  defp update_request do
    %Schema{
      title: "FilterUpdateRequest",
      type: :object,
      properties: %{
        phrase: %Schema{type: :string, description: "The text to be filtered"},
        context: %Schema{
          type: :array,
          items: %Schema{type: :string, enum: ["home", "notifications", "public", "thread"]},
          description:
            "Array of enumerable strings `home`, `notifications`, `public`, `thread`. At least one context must be specified."
        },
        irreversible: %Schema{
          allOf: [BooleanLike],
          nullable: true,
          description:
            "Should the server irreversibly drop matching entities from home and notifications?"
        },
        whole_word: %Schema{
          allOf: [BooleanLike],
          nullable: true,
          description: "Consider word boundaries?",
          default: true
        },
        expires_in: %Schema{
          nullable: true,
          type: :integer,
          description:
            "Number of seconds from now the filter should expire. Otherwise, null for a filter that doesn't expire."
        }
      },
      required: [:phrase, :context],
      example: %{
        "phrase" => "knights",
        "context" => ["home"]
      }
    }
  end
end
