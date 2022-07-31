# Pleroma: A lightweight social networking server
# Copyright © 2017-2022 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.ApiSpec.AppOperation do
  alias OpenApiSpex.Operation
  alias OpenApiSpex.Schema
  alias Pleroma.Web.ApiSpec.Helpers
  alias Pleroma.Web.ApiSpec.Schemas.App

  @spec open_api_operation(atom) :: Operation.t()
  def open_api_operation(action) do
    operation = String.to_existing_atom("#{action}_operation")
    apply(__MODULE__, operation, [])
  end

  @spec create_operation() :: Operation.t()
  def create_operation do
    %Operation{
      tags: ["Applications"],
      summary: "Create an application",
      description: "Create a new application to obtain OAuth2 credentials",
      operationId: "AppController.create",
      requestBody: Helpers.request_body("Parameters", create_request(), required: true),
      responses: %{
        200 => Operation.response("App", "application/json", App),
        422 =>
          Operation.response(
            "Unprocessable Entity",
            "application/json",
            %Schema{
              type: :object,
              description:
                "If a required parameter is missing or improperly formatted, the request will fail.",
              properties: %{
                error: %Schema{type: :string}
              },
              example: %{
                "error" => "Validation failed: Redirect URI must be an absolute URI."
              }
            }
          )
      }
    }
  end

  def verify_credentials_operation do
    %Operation{
      tags: ["Applications"],
      summary: "Verify the application works",
      description: "Confirm that the app's OAuth2 credentials work.",
      operationId: "AppController.verify_credentials",
      security: [%{"oAuth" => ["read"]}],
      responses: %{
        200 =>
          Operation.response("App", "application/json", %Schema{
            type: :object,
            description:
              "If the Authorization header was provided with a valid token, you should see your app returned as an Application entity.",
            properties: %{
              name: %Schema{type: :string},
              vapid_key: %Schema{type: :string},
              website: %Schema{type: :string, nullable: true}
            },
            example: %{
              "name" => "My App",
              "vapid_key" =>
                "BCk-QqERU0q-CfYZjcuB6lnyyOYfJ2AifKqfeGIm7Z-HiTU5T9eTG5GxVA0_OH5mMlI4UkkDTpaZwozy0TzdZ2M=",
              "website" => "https://myapp.com/"
            }
          }),
        422 =>
          Operation.response(
            "Unauthorized",
            "application/json",
            %Schema{
              type: :object,
              description:
                "If the Authorization header contains an invalid token, is malformed, or is not present, an error will be returned indicating an authorization failure.",
              properties: %{
                error: %Schema{type: :string}
              },
              example: %{
                "error" => "The access token is invalid."
              }
            }
          )
      }
    }
  end

  defp create_request do
    %Schema{
      title: "AppCreateRequest",
      description: "POST body for creating an app",
      type: :object,
      properties: %{
        client_name: %Schema{type: :string, description: "A name for your application."},
        redirect_uris: %Schema{
          type: :string,
          description:
            "Where the user should be redirected after authorization. To display the authorization code to the user instead of redirecting to a web page, use `urn:ietf:wg:oauth:2.0:oob` in this parameter."
        },
        scopes: %Schema{
          type: :string,
          description: "Space separated list of scopes",
          default: "read"
        },
        website: %Schema{
          type: :string,
          nullable: true,
          description: "A URL to the homepage of your app"
        }
      },
      required: [:client_name, :redirect_uris],
      example: %{
        "client_name" => "My App",
        "redirect_uris" => "https://myapp.com/auth/callback",
        "website" => "https://myapp.com/"
      }
    }
  end
end
