# Pleroma: A lightweight social networking server
# Copyright © 2017-2020 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.ApiSpec.AccountOperation do
  alias OpenApiSpex.Operation
  alias OpenApiSpex.Reference
  alias OpenApiSpex.Schema
  alias Pleroma.Web.ApiSpec.Helpers
  alias Pleroma.Web.ApiSpec.Schemas.Account
  alias Pleroma.Web.ApiSpec.Schemas.AccountCreateRequest
  alias Pleroma.Web.ApiSpec.Schemas.AccountCreateResponse
  alias Pleroma.Web.ApiSpec.Schemas.AccountMuteRequest
  alias Pleroma.Web.ApiSpec.Schemas.AccountRelationship
  alias Pleroma.Web.ApiSpec.Schemas.AccountRelationshipsResponse
  alias Pleroma.Web.ApiSpec.Schemas.AccountsResponse
  alias Pleroma.Web.ApiSpec.Schemas.AccountUpdateCredentialsRequest
  alias Pleroma.Web.ApiSpec.Schemas.BooleanLike
  alias Pleroma.Web.ApiSpec.Schemas.ListsResponse
  alias Pleroma.Web.ApiSpec.Schemas.StatusesResponse
  alias Pleroma.Web.ApiSpec.Schemas.VisibilityScope

  @spec open_api_operation(atom) :: Operation.t()
  def open_api_operation(action) do
    operation = String.to_existing_atom("#{action}_operation")
    apply(__MODULE__, operation, [])
  end

  @spec create_operation() :: Operation.t()
  def create_operation do
    %Operation{
      tags: ["accounts"],
      summary: "Register an account",
      description:
        "Creates a user and account records. Returns an account access token for the app that initiated the request. The app should save this token for later, and should wait for the user to confirm their account by clicking a link in their email inbox.",
      operationId: "AccountController.create",
      requestBody: Helpers.request_body("Parameters", AccountCreateRequest, required: true),
      responses: %{
        200 => Operation.response("Account", "application/json", AccountCreateResponse)
      }
    }
  end

  def verify_credentials_operation do
    %Operation{
      tags: ["accounts"],
      description: "Test to make sure that the user token works.",
      summary: "Verify account credentials",
      operationId: "AccountController.verify_credentials",
      security: [%{"oAuth" => ["read:accounts"]}],
      responses: %{
        200 => Operation.response("Account", "application/json", Account)
      }
    }
  end

  def update_credentials_operation do
    %Operation{
      tags: ["accounts"],
      summary: "Update account credentials",
      description: "Update the user's display and preferences.",
      operationId: "AccountController.update_credentials",
      security: [%{"oAuth" => ["write:accounts"]}],
      requestBody:
        Helpers.request_body("Parameters", AccountUpdateCredentialsRequest, required: true),
      responses: %{
        200 => Operation.response("Account", "application/json", Account)
      }
    }
  end

  def relationships_operation do
    %Operation{
      tags: ["accounts"],
      summary: "Check relationships to other accounts",
      operationId: "AccountController.relationships",
      description: "Find out whether a given account is followed, blocked, muted, etc.",
      security: [%{"oAuth" => ["read:follows"]}],
      parameters: [
        Operation.parameter(
          :id,
          :query,
          %Schema{
            oneOf: [%Schema{type: :array, items: %Schema{type: :string}}, %Schema{type: :string}]
          },
          "Account IDs",
          example: "123"
        )
      ],
      responses: %{
        200 => Operation.response("Account", "application/json", AccountRelationshipsResponse)
      }
    }
  end

  def show_operation do
    %Operation{
      tags: ["accounts"],
      summary: "Account",
      operationId: "AccountController.show",
      description: "View information about a profile.",
      parameters: [%Reference{"$ref": "#/components/parameters/accountIdOrNickname"}],
      responses: %{
        200 => Operation.response("Account", "application/json", Account)
      }
    }
  end

  def statuses_operation do
    %Operation{
      tags: ["accounts"],
      summary: "Statuses",
      operationId: "AccountController.statuses",
      description:
        "Statuses posted to the given account. Public (for public statuses only), or user token + `read:statuses` (for private statuses the user is authorized to see)",
      parameters: [
        %Reference{"$ref": "#/components/parameters/accountIdOrNickname"},
        Operation.parameter(:pinned, :query, BooleanLike, "Pinned"),
        Operation.parameter(:tagged, :query, :string, "With tag"),
        Operation.parameter(:only_media, :query, BooleanLike, "Only meadia"),
        Operation.parameter(:with_muted, :query, BooleanLike, "With muted"),
        Operation.parameter(:exclude_reblogs, :query, BooleanLike, "Exclude reblobs"),
        Operation.parameter(
          :exclude_visibilities,
          :query,
          %Schema{type: :array, items: VisibilityScope},
          "Exclude visibilities"
        ),
        Operation.parameter(:max_id, :query, :string, "Max ID"),
        Operation.parameter(:min_id, :query, :string, "Mix ID"),
        Operation.parameter(:since_id, :query, :string, "Since ID"),
        Operation.parameter(
          :limit,
          :query,
          %Schema{type: :integer, default: 20, maximum: 40},
          "Limit"
        )
      ],
      responses: %{
        200 => Operation.response("Statuses", "application/json", StatusesResponse)
      }
    }
  end

  def followers_operation do
    %Operation{
      tags: ["accounts"],
      summary: "Followers",
      operationId: "AccountController.followers",
      security: [%{"oAuth" => ["read:accounts"]}],
      description:
        "Accounts which follow the given account, if network is not hidden by the account owner.",
      parameters: [
        %Reference{"$ref": "#/components/parameters/accountIdOrNickname"},
        Operation.parameter(:max_id, :query, :string, "Max ID"),
        Operation.parameter(:min_id, :query, :string, "Mix ID"),
        Operation.parameter(:since_id, :query, :string, "Since ID"),
        Operation.parameter(
          :limit,
          :query,
          %Schema{type: :integer, default: 20, maximum: 40},
          "Limit"
        )
      ],
      responses: %{
        200 => Operation.response("Accounts", "application/json", AccountsResponse)
      }
    }
  end

  def following_operation do
    %Operation{
      tags: ["accounts"],
      summary: "Following",
      operationId: "AccountController.following",
      security: [%{"oAuth" => ["read:accounts"]}],
      description:
        "Accounts which the given account is following, if network is not hidden by the account owner.",
      parameters: [
        %Reference{"$ref": "#/components/parameters/accountIdOrNickname"},
        Operation.parameter(:max_id, :query, :string, "Max ID"),
        Operation.parameter(:min_id, :query, :string, "Mix ID"),
        Operation.parameter(:since_id, :query, :string, "Since ID"),
        Operation.parameter(
          :limit,
          :query,
          %Schema{type: :integer, default: 20, maximum: 40},
          "Limit"
        )
      ],
      responses: %{200 => Operation.response("Accounts", "application/json", AccountsResponse)}
    }
  end

  def lists_operation do
    %Operation{
      tags: ["accounts"],
      summary: "Lists containing this account",
      operationId: "AccountController.lists",
      security: [%{"oAuth" => ["read:lists"]}],
      description: "User lists that you have added this account to.",
      parameters: [%Reference{"$ref": "#/components/parameters/accountIdOrNickname"}],
      responses: %{200 => Operation.response("Lists", "application/json", ListsResponse)}
    }
  end

  def follow_operation do
    %Operation{
      tags: ["accounts"],
      summary: "Follow",
      operationId: "AccountController.follow",
      security: [%{"oAuth" => ["follow", "write:follows"]}],
      description: "Follow the given account",
      parameters: [
        %Reference{"$ref": "#/components/parameters/accountIdOrNickname"},
        Operation.parameter(
          :reblogs,
          :query,
          BooleanLike,
          "Receive this account's reblogs in home timeline? Defaults to true."
        )
      ],
      responses: %{
        200 => Operation.response("Relationship", "application/json", AccountRelationship)
      }
    }
  end

  def unfollow_operation do
    %Operation{
      tags: ["accounts"],
      summary: "Unfollow",
      operationId: "AccountController.unfollow",
      security: [%{"oAuth" => ["follow", "write:follows"]}],
      description: "Unfollow the given account",
      parameters: [%Reference{"$ref": "#/components/parameters/accountIdOrNickname"}],
      responses: %{
        200 => Operation.response("Relationship", "application/json", AccountRelationship)
      }
    }
  end

  def mute_operation do
    %Operation{
      tags: ["accounts"],
      summary: "Mute",
      operationId: "AccountController.mute",
      security: [%{"oAuth" => ["follow", "write:mutes"]}],
      requestBody: Helpers.request_body("Parameters", AccountMuteRequest),
      description:
        "Mute the given account. Clients should filter statuses and notifications from this account, if received (e.g. due to a boost in the Home timeline).",
      parameters: [
        %Reference{"$ref": "#/components/parameters/accountIdOrNickname"},
        Operation.parameter(
          :notifications,
          :query,
          %Schema{allOf: [BooleanLike], default: true},
          "Mute notifications in addition to statuses? Defaults to `true`."
        )
      ],
      responses: %{
        200 => Operation.response("Relationship", "application/json", AccountRelationship)
      }
    }
  end

  def unmute_operation do
    %Operation{
      tags: ["accounts"],
      summary: "Unmute",
      operationId: "AccountController.unmute",
      security: [%{"oAuth" => ["follow", "write:mutes"]}],
      description: "Unmute the given account.",
      parameters: [%Reference{"$ref": "#/components/parameters/accountIdOrNickname"}],
      responses: %{
        200 => Operation.response("Relationship", "application/json", AccountRelationship)
      }
    }
  end

  def block_operation do
    %Operation{
      tags: ["accounts"],
      summary: "Block",
      operationId: "AccountController.block",
      security: [%{"oAuth" => ["follow", "write:blocks"]}],
      description:
        "Block the given account. Clients should filter statuses from this account if received (e.g. due to a boost in the Home timeline)",
      parameters: [%Reference{"$ref": "#/components/parameters/accountIdOrNickname"}],
      responses: %{
        200 => Operation.response("Relationship", "application/json", AccountRelationship)
      }
    }
  end

  def unblock_operation do
    %Operation{
      tags: ["accounts"],
      summary: "Unblock",
      operationId: "AccountController.unblock",
      security: [%{"oAuth" => ["follow", "write:blocks"]}],
      description: "Unblock the given account.",
      parameters: [%Reference{"$ref": "#/components/parameters/accountIdOrNickname"}],
      responses: %{
        200 => Operation.response("Relationship", "application/json", AccountRelationship)
      }
    }
  end

  def follows_operation, do: :ok
  def mutes_operation, do: :ok
  def blocks_operation, do: :ok
  def endorsements_operation, do: :ok
end
