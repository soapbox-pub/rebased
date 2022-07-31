# Pleroma: A lightweight social networking server
# Copyright © 2017-2022 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.ApiSpec.Admin.OAuthAppOperation do
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
      summary: "Retrieve a list of OAuth applications",
      tags: ["OAuth application managment"],
      operationId: "AdminAPI.OAuthAppController.index",
      security: [%{"oAuth" => ["admin:write"]}],
      parameters: [
        Operation.parameter(:name, :query, %Schema{type: :string}, "App name"),
        Operation.parameter(:client_id, :query, %Schema{type: :string}, "Client ID"),
        Operation.parameter(:page, :query, %Schema{type: :integer, default: 1}, "Page"),
        Operation.parameter(
          :trusted,
          :query,
          %Schema{type: :boolean, default: false},
          "Trusted apps"
        ),
        Operation.parameter(
          :page_size,
          :query,
          %Schema{type: :integer, default: 50},
          "Number of apps to return"
        )
        | admin_api_params()
      ],
      responses: %{
        200 =>
          Operation.response("List of apps", "application/json", %Schema{
            type: :object,
            properties: %{
              apps: %Schema{type: :array, items: oauth_app()},
              count: %Schema{type: :integer},
              page_size: %Schema{type: :integer}
            },
            example: %{
              "apps" => [
                %{
                  "id" => 1,
                  "name" => "App name",
                  "client_id" => "yHoDSiWYp5mPV6AfsaVOWjdOyt5PhWRiafi6MRd1lSk",
                  "client_secret" => "nLmis486Vqrv2o65eM9mLQx_m_4gH-Q6PcDpGIMl6FY",
                  "redirect_uri" => "https://example.com/oauth-callback",
                  "website" => "https://example.com",
                  "trusted" => true
                }
              ],
              "count" => 1,
              "page_size" => 50
            }
          })
      }
    }
  end

  def create_operation do
    %Operation{
      tags: ["OAuth application managment"],
      summary: "Create an OAuth application",
      operationId: "AdminAPI.OAuthAppController.create",
      requestBody: request_body("Parameters", create_request()),
      parameters: admin_api_params(),
      security: [%{"oAuth" => ["admin:write"]}],
      responses: %{
        200 => Operation.response("App", "application/json", oauth_app()),
        400 => Operation.response("Bad Request", "application/json", ApiError)
      }
    }
  end

  def update_operation do
    %Operation{
      tags: ["OAuth application managment"],
      summary: "Update OAuth application",
      operationId: "AdminAPI.OAuthAppController.update",
      parameters: [id_param() | admin_api_params()],
      security: [%{"oAuth" => ["admin:write"]}],
      requestBody: request_body("Parameters", update_request()),
      responses: %{
        200 => Operation.response("App", "application/json", oauth_app()),
        400 =>
          Operation.response("Bad Request", "application/json", %Schema{
            oneOf: [ApiError, %Schema{type: :string}]
          })
      }
    }
  end

  def delete_operation do
    %Operation{
      tags: ["OAuth application managment"],
      summary: "Delete OAuth application",
      operationId: "AdminAPI.OAuthAppController.delete",
      parameters: [id_param() | admin_api_params()],
      security: [%{"oAuth" => ["admin:write"]}],
      responses: %{
        204 => no_content_response(),
        400 => no_content_response()
      }
    }
  end

  defp create_request do
    %Schema{
      title: "oAuthAppCreateRequest",
      type: :object,
      required: [:name, :redirect_uris],
      properties: %{
        name: %Schema{type: :string, description: "Application Name"},
        scopes: %Schema{type: :array, items: %Schema{type: :string}, description: "oAuth scopes"},
        redirect_uris: %Schema{
          type: :string,
          description:
            "Where the user should be redirected after authorization. To display the authorization code to the user instead of redirecting to a web page, use `urn:ietf:wg:oauth:2.0:oob` in this parameter."
        },
        website: %Schema{
          type: :string,
          nullable: true,
          description: "A URL to the homepage of the app"
        },
        trusted: %Schema{
          type: :boolean,
          nullable: true,
          default: false,
          description: "Is the app trusted?"
        }
      },
      example: %{
        "name" => "My App",
        "redirect_uris" => "https://myapp.com/auth/callback",
        "website" => "https://myapp.com/",
        "scopes" => ["read", "write"],
        "trusted" => true
      }
    }
  end

  defp update_request do
    %Schema{
      title: "oAuthAppUpdateRequest",
      type: :object,
      properties: %{
        name: %Schema{type: :string, description: "Application Name"},
        scopes: %Schema{type: :array, items: %Schema{type: :string}, description: "oAuth scopes"},
        redirect_uris: %Schema{
          type: :string,
          description:
            "Where the user should be redirected after authorization. To display the authorization code to the user instead of redirecting to a web page, use `urn:ietf:wg:oauth:2.0:oob` in this parameter."
        },
        website: %Schema{
          type: :string,
          nullable: true,
          description: "A URL to the homepage of the app"
        },
        trusted: %Schema{
          type: :boolean,
          nullable: true,
          default: false,
          description: "Is the app trusted?"
        }
      },
      example: %{
        "name" => "My App",
        "redirect_uris" => "https://myapp.com/auth/callback",
        "website" => "https://myapp.com/",
        "scopes" => ["read", "write"],
        "trusted" => true
      }
    }
  end

  defp oauth_app do
    %Schema{
      title: "oAuthApp",
      type: :object,
      properties: %{
        id: %Schema{type: :integer},
        name: %Schema{type: :string},
        client_id: %Schema{type: :string},
        client_secret: %Schema{type: :string},
        redirect_uri: %Schema{type: :string},
        website: %Schema{type: :string, nullable: true},
        trusted: %Schema{type: :boolean}
      },
      example: %{
        "id" => 123,
        "name" => "My App",
        "client_id" => "TWhM-tNSuncnqN7DBJmoyeLnk6K3iJJ71KKXxgL1hPM",
        "client_secret" => "ZEaFUFmF0umgBX1qKJDjaU99Q31lDkOU8NutzTOoliw",
        "redirect_uri" => "https://myapp.com/oauth-callback",
        "website" => "https://myapp.com/",
        "trusted" => false
      }
    }
  end

  def id_param do
    Operation.parameter(:id, :path, :integer, "App ID",
      example: 1337,
      required: true
    )
  end
end
