# Pleroma: A lightweight social networking server
# Copyright © 2017-2022 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.ApiSpec.SearchOperation do
  alias OpenApiSpex.Operation
  alias OpenApiSpex.Schema
  alias Pleroma.Web.ApiSpec.AccountOperation
  alias Pleroma.Web.ApiSpec.Schemas.Account
  alias Pleroma.Web.ApiSpec.Schemas.BooleanLike
  alias Pleroma.Web.ApiSpec.Schemas.FlakeID
  alias Pleroma.Web.ApiSpec.Schemas.Status
  alias Pleroma.Web.ApiSpec.Schemas.Tag

  import Pleroma.Web.ApiSpec.Helpers

  def open_api_operation(action) do
    operation = String.to_existing_atom("#{action}_operation")
    apply(__MODULE__, operation, [])
  end

  # Note: `with_relationships` param is not supported (PleromaFE uses this op for autocomplete)
  def account_search_operation do
    %Operation{
      tags: ["Search"],
      summary: "Search for matching accounts by username or display name",
      operationId: "SearchController.account_search",
      parameters: [
        Operation.parameter(:q, :query, %Schema{type: :string}, "What to search for",
          required: true
        ),
        Operation.parameter(
          :limit,
          :query,
          %Schema{type: :integer, default: 40},
          "Maximum number of results"
        ),
        Operation.parameter(
          :resolve,
          :query,
          %Schema{allOf: [BooleanLike], default: false},
          "Attempt WebFinger lookup. Use this when `q` is an exact address."
        ),
        Operation.parameter(
          :following,
          :query,
          %Schema{allOf: [BooleanLike], default: false},
          "Only include accounts that the user is following"
        )
      ],
      responses: %{
        200 =>
          Operation.response(
            "Array of Account",
            "application/json",
            AccountOperation.array_of_accounts()
          )
      }
    }
  end

  def search_operation do
    %Operation{
      tags: ["Search"],
      summary: "Search results",
      security: [%{"oAuth" => ["read:search"]}],
      operationId: "SearchController.search",
      deprecated: true,
      parameters: [
        Operation.parameter(
          :account_id,
          :query,
          FlakeID,
          "If provided, statuses returned will be authored only by this account"
        ),
        Operation.parameter(
          :type,
          :query,
          %Schema{type: :string, enum: ["accounts", "hashtags", "statuses"]},
          "Search type"
        ),
        Operation.parameter(:q, :query, %Schema{type: :string}, "The search query", required: true),
        Operation.parameter(
          :resolve,
          :query,
          %Schema{allOf: [BooleanLike], default: false},
          "Attempt WebFinger lookup"
        ),
        Operation.parameter(
          :following,
          :query,
          %Schema{allOf: [BooleanLike], default: false},
          "Only include accounts that the user is following"
        ),
        Operation.parameter(
          :offset,
          :query,
          %Schema{type: :integer},
          "Offset"
        ),
        with_relationships_param() | pagination_params()
      ],
      responses: %{
        200 => Operation.response("Results", "application/json", results())
      }
    }
  end

  def search2_operation do
    %Operation{
      tags: ["Search"],
      summary: "Search results",
      security: [%{"oAuth" => ["read:search"]}],
      operationId: "SearchController.search2",
      parameters: [
        Operation.parameter(
          :account_id,
          :query,
          FlakeID,
          "If provided, statuses returned will be authored only by this account"
        ),
        Operation.parameter(
          :type,
          :query,
          %Schema{type: :string, enum: ["accounts", "hashtags", "statuses"]},
          "Search type"
        ),
        Operation.parameter(:q, :query, %Schema{type: :string}, "What to search for",
          required: true
        ),
        Operation.parameter(
          :resolve,
          :query,
          %Schema{allOf: [BooleanLike], default: false},
          "Attempt WebFinger lookup"
        ),
        Operation.parameter(
          :following,
          :query,
          %Schema{allOf: [BooleanLike], default: false},
          "Only include accounts that the user is following"
        ),
        with_relationships_param() | pagination_params()
      ],
      responses: %{
        200 => Operation.response("Results", "application/json", results2())
      }
    }
  end

  defp results2 do
    %Schema{
      title: "SearchResults",
      type: :object,
      properties: %{
        accounts: %Schema{
          type: :array,
          items: Account,
          description: "Accounts which match the given query"
        },
        statuses: %Schema{
          type: :array,
          items: Status,
          description: "Statuses which match the given query"
        },
        hashtags: %Schema{
          type: :array,
          items: Tag,
          description: "Hashtags which match the given query"
        }
      },
      example: %{
        "accounts" => [Account.schema().example],
        "statuses" => [Status.schema().example],
        "hashtags" => [Tag.schema().example]
      }
    }
  end

  defp results do
    %Schema{
      title: "SearchResults",
      type: :object,
      properties: %{
        accounts: %Schema{
          type: :array,
          items: Account,
          description: "Accounts which match the given query"
        },
        statuses: %Schema{
          type: :array,
          items: Status,
          description: "Statuses which match the given query"
        },
        hashtags: %Schema{
          type: :array,
          items: %Schema{type: :string},
          description: "Hashtags which match the given query"
        }
      },
      example: %{
        "accounts" => [Account.schema().example],
        "statuses" => [Status.schema().example],
        "hashtags" => ["cofe"]
      }
    }
  end
end
