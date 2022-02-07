# Pleroma: A lightweight social networking server
# Copyright © 2017-2022 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.ApiSpec.MastodonAdmin.AccountOperation do
  alias OpenApiSpex.Operation
  alias OpenApiSpex.Schema
  alias Pleroma.Web.ApiSpec.Schemas.Account
  alias Pleroma.Web.ApiSpec.Schemas.ApiError
  alias Pleroma.Web.ApiSpec.Schemas.FlakeID

  import Pleroma.Web.ApiSpec.Helpers

  def open_api_operation(action) do
    operation = String.to_existing_atom("#{action}_operation")
    apply(__MODULE__, operation, [])
  end

  def index_operation do
    %Operation{
      tags: ["User administration"],
      summary: "View accounts by criteria",
      operationId: "Admin.AccountController.index",
      description: "View accounts matching certain criteria for filtering, up to 100 at a time.",
      security: [%{"oAuth" => ["admin:read:accounts"]}],
      parameters:
        [
          Operation.parameter(:local, :query, :boolean, "Filter for local accounts?"),
          Operation.parameter(:remote, :query, :boolean, "Filter for remote accounts?"),
          Operation.parameter(
            :by_domain,
            :query,
            :string,
            "Filter by the given domain (not implemented yet)"
          ),
          Operation.parameter(
            :active,
            :query,
            :boolean,
            "Filter for currently active accounts??"
          ),
          Operation.parameter(
            :pending,
            :query,
            :boolean,
            "Filter for currently pending accounts?"
          ),
          Operation.parameter(
            :disabled,
            :query,
            :boolean,
            "Filter for currently disabled accounts?"
          ),
          Operation.parameter(
            :sensitized,
            :query,
            :boolean,
            "Filter for currently sensitized accounts? (not implemented yet)"
          ),
          Operation.parameter(
            :silenced,
            :query,
            :boolean,
            "Filter for currently silenced accounts? (not implemented yet)"
          ),
          Operation.parameter(
            :suspended,
            :query,
            :boolean,
            "Filter for currently suspended accounts? (not implemented yet)"
          ),
          Operation.parameter(:username, :query, :string, "Username to search for"),
          Operation.parameter(:display_name, :query, :string, "Display name to search for"),
          Operation.parameter(:email, :query, :string, "Lookup a user with this email"),
          Operation.parameter(
            :ip,
            :query,
            :string,
            "Lookup users by this IP address (not implemented yet)"
          ),
          Operation.parameter(:staff, :query, :boolean, "Filter for staff accounts?")
        ] ++
          pagination_params(),
      responses: %{
        200 =>
          Operation.response("Account", "application/json", %Schema{
            title: "ArrayOfAccounts",
            type: :array,
            items: account()
          }),
        401 => Operation.response("Error", "application/json", ApiError)
      }
    }
  end

  def show_operation do
    %Operation{
      tags: ["User administration"],
      summary: "View a specific account",
      operationId: "Admin.AccountController.show",
      description: "View admin-level information about the given account.",
      security: [%{"oAuth" => ["admin:read:accounts"]}],
      parameters: [
        Operation.parameter(:id, :path, :string, "ID of the account")
      ],
      responses: %{
        200 => Operation.response("Account", "application/json", account()),
        401 => Operation.response("Error", "application/json", ApiError),
        404 => Operation.response("Error", "application/json", ApiError)
      }
    }
  end

  def account_action_operation do
    %Operation{
      tags: ["User administration"],
      summary: "Perform an action against an account",
      operationId: "Admin.AccountController.account_action",
      description:
        "Perform an action against an account and log this action in the moderation history.",
      security: [%{"oAuth" => ["admin:write:accounts"]}],
      parameters: [
        Operation.parameter(:id, :path, :string, "ID of the account")
      ],
      requestBody:
        request_body(
          "Parameters",
          %Schema{
            type: :object,
            properties: %{
              type: %Schema{
                type: :string,
                enum: ["none", "disable", "sensitive", "silence", "suspend"]
              }
            }
          },
          required: true
        ),
      responses: %{
        204 => no_content_response(),
        401 => Operation.response("Error", "application/json", ApiError)
      }
    }
  end

  def delete_operation do
    %Operation{
      tags: ["User administration"],
      summary: "Delete a specific account",
      operationId: "Admin.AccountController.delete",
      description: "Delete the given account.",
      security: [%{"oAuth" => ["admin:write:accounts"]}],
      parameters: [
        Operation.parameter(:id, :path, :string, "ID of the account")
      ],
      responses: %{
        200 => Operation.response("Account", "application/json", account()),
        401 => Operation.response("Error", "application/json", ApiError),
        404 => Operation.response("Error", "application/json", ApiError)
      }
    }
  end

  def enable_operation do
    %Operation{
      tags: ["User administration"],
      summary: "Re-enable account",
      operationId: "Admin.AccountController.enable",
      description: "Re-enable a local account whose login is currently disabled.",
      security: [%{"oAuth" => ["admin:write:accounts"]}],
      parameters: [
        Operation.parameter(:id, :path, :string, "ID of the account")
      ],
      responses: %{
        200 => Operation.response("Account", "application/json", account()),
        401 => Operation.response("Error", "application/json", ApiError),
        404 => Operation.response("Error", "application/json", ApiError)
      }
    }
  end

  def unsensitive_operation do
    %Operation{
      tags: ["User administration"],
      summary: "Unsensitive account",
      operationId: "Admin.AccountController.unsensitive",
      description: "Unsensitive a currently sensitized account.",
      security: [%{"oAuth" => ["admin:write:accounts"]}],
      parameters: [
        Operation.parameter(:id, :path, :string, "ID of the account")
      ],
      responses: %{
        200 => Operation.response("Account", "application/json", account()),
        401 => Operation.response("Error", "application/json", ApiError),
        404 => Operation.response("Error", "application/json", ApiError)
      }
    }
  end

  def unsilence_operation do
    %Operation{
      tags: ["User administration"],
      summary: "Unsilence account",
      operationId: "Admin.AccountController.unsilence",
      description: "Unsilence a currently silenced account.",
      parameters: [
        Operation.parameter(:id, :path, :string, "ID of the account")
      ],
      responses: %{
        200 => Operation.response("Account", "application/json", account()),
        401 => Operation.response("Error", "application/json", ApiError),
        404 => Operation.response("Error", "application/json", ApiError)
      }
    }
  end

  def unsuspend_operation do
    %Operation{
      tags: ["User administration"],
      summary: "Unsuspend account",
      operationId: "Admin.AccountController.unsuspend",
      description: "Unsuspend a currently suspended account.",
      parameters: [
        Operation.parameter(:id, :path, :string, "ID of the account")
      ],
      responses: %{
        200 => Operation.response("Account", "application/json", account()),
        401 => Operation.response("Error", "application/json", ApiError),
        404 => Operation.response("Error", "application/json", ApiError)
      }
    }
  end

  def approve_operation do
    %Operation{
      tags: ["User administration"],
      summary: "Approve pending account",
      operationId: "Admin.AccountController.approve",
      description: "Approve the given local account if it is currently pending approval.",
      parameters: [
        Operation.parameter(:id, :path, :string, "ID of the account")
      ],
      responses: %{
        200 => Operation.response("Account", "application/json", account()),
        401 => Operation.response("Error", "application/json", ApiError),
        404 => Operation.response("Error", "application/json", ApiError)
      }
    }
  end

  def reject_operation do
    %Operation{
      tags: ["User administration"],
      summary: "Reject pending account",
      operationId: "Admin.AccountController.reject",
      description: "Reject the given local account if it is currently pending approval.",
      parameters: [
        Operation.parameter(:id, :path, :string, "ID of the account")
      ],
      responses: %{
        200 => Operation.response("Account", "application/json", account()),
        400 => Operation.response("Error", "application/json", ApiError),
        401 => Operation.response("Error", "application/json", ApiError),
        404 => Operation.response("Error", "application/json", ApiError)
      }
    }
  end

  defp account do
    %Schema{
      title: "AdminAccount",
      description: "Admin-level information about a given account.",
      type: :object,
      properties: %{
        id: FlakeID,
        username: %Schema{type: :string},
        domain: %Schema{type: :string, nullable: true},
        created_at: %Schema{type: :string, format: "date-time"},
        email: %Schema{type: :string, format: "email", nullable: true},
        ip: %Schema{type: :string, nullable: true},
        role: %Schema{type: :string, nullable: true},
        confirmed: %Schema{type: :boolean},
        sensitized: %Schema{type: :boolean, nullable: true},
        silenced: %Schema{type: :boolean, nullable: true},
        suspened: %Schema{type: :boolean, nullable: true},
        disabled: %Schema{type: :boolean},
        approved: %Schema{type: :boolean},
        locale: %Schema{type: :string, format: "date-time", nullable: true},
        invite_request: %Schema{type: :string, format: "date-time", nullable: true},
        account: Account
      }
    }
  end
end
