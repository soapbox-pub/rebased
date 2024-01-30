# Pleroma: A lightweight social networking server
# Copyright © 2017-2022 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.ApiSpec.Admin.InviteOperation do
  alias OpenApiSpex.Operation
  alias OpenApiSpex.Schema
  alias Pleroma.Web.ApiSpec.Schemas.ApiError

  import Pleroma.Web.ApiSpec.Helpers

  def open_api_operation(action) do
    operation = String.to_existing_atom("#{action}_operation")
    apply(__MODULE__, operation, [])
  end

  def index_operation do
    %Operation{
      tags: ["Invites"],
      summary: "Get a list of generated invites",
      operationId: "AdminAPI.InviteController.index",
      security: [%{"oAuth" => ["admin:read:invites"]}],
      parameters: admin_api_params(),
      responses: %{
        200 =>
          Operation.response("Invites", "application/json", %Schema{
            type: :object,
            properties: %{
              invites: %Schema{type: :array, items: invite()}
            },
            example: %{
              "invites" => [
                %{
                  "id" => 123,
                  "token" => "kSQtDj_GNy2NZsL9AQDFIsHN5qdbguB6qRg3WHw6K1U=",
                  "used" => true,
                  "expires_at" => nil,
                  "uses" => 0,
                  "max_use" => nil,
                  "invite_type" => "one_time"
                }
              ]
            }
          })
      }
    }
  end

  def create_operation do
    %Operation{
      tags: ["Invites"],
      summary: "Create an account registration invite token",
      operationId: "AdminAPI.InviteController.create",
      security: [%{"oAuth" => ["admin:write:invites"]}],
      parameters: admin_api_params(),
      requestBody:
        request_body("Parameters", %Schema{
          type: :object,
          properties: %{
            max_use: %Schema{type: :integer},
            expires_at: %Schema{type: :string, format: :date, example: "2020-04-20"}
          }
        }),
      responses: %{
        200 => Operation.response("Invite", "application/json", invite())
      }
    }
  end

  def revoke_operation do
    %Operation{
      tags: ["Invites"],
      summary: "Revoke invite by token",
      operationId: "AdminAPI.InviteController.revoke",
      security: [%{"oAuth" => ["admin:write:invites"]}],
      parameters: admin_api_params(),
      requestBody:
        request_body(
          "Parameters",
          %Schema{
            type: :object,
            required: [:token],
            properties: %{
              token: %Schema{type: :string}
            }
          },
          required: true
        ),
      responses: %{
        200 => Operation.response("Invite", "application/json", invite()),
        400 => Operation.response("Bad Request", "application/json", ApiError),
        404 => Operation.response("Not Found", "application/json", ApiError)
      }
    }
  end

  def email_operation do
    %Operation{
      tags: ["Invites"],
      summary: "Sends registration invite via email",
      operationId: "AdminAPI.InviteController.email",
      security: [%{"oAuth" => ["admin:write:invites"]}],
      parameters: admin_api_params(),
      requestBody:
        request_body(
          "Parameters",
          %Schema{
            type: :object,
            required: [:email],
            properties: %{
              email: %Schema{type: :string, format: :email},
              name: %Schema{type: :string}
            }
          },
          required: true
        ),
      responses: %{
        204 => no_content_response(),
        400 => Operation.response("Bad Request", "application/json", ApiError),
        403 => Operation.response("Forbidden", "application/json", ApiError)
      }
    }
  end

  defp invite do
    %Schema{
      title: "Invite",
      type: :object,
      properties: %{
        id: %Schema{type: :integer},
        token: %Schema{type: :string},
        used: %Schema{type: :boolean},
        expires_at: %Schema{type: :string, format: :date, nullable: true},
        uses: %Schema{type: :integer},
        max_use: %Schema{type: :integer, nullable: true},
        invite_type: %Schema{
          type: :string,
          enum: ["one_time", "reusable", "date_limited", "reusable_date_limited"]
        }
      },
      example: %{
        "id" => 123,
        "token" => "kSQtDj_GNy2NZsL9AQDFIsHN5qdbguB6qRg3WHw6K1U=",
        "used" => true,
        "expires_at" => nil,
        "uses" => 0,
        "max_use" => nil,
        "invite_type" => "one_time"
      }
    }
  end
end
