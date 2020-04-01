# Pleroma: A lightweight social networking server
# Copyright © 2017-2020 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.ApiSpec.AppOperation do
  alias OpenApiSpex.Operation
  alias OpenApiSpex.Schema
  alias Pleroma.Web.ApiSpec.Schemas.AppCreateRequest
  alias Pleroma.Web.ApiSpec.Schemas.AppCreateResponse

  @spec open_api_operation(atom) :: Operation.t()
  def open_api_operation(action) do
    operation = String.to_existing_atom("#{action}_operation")
    apply(__MODULE__, operation, [])
  end

  @spec create_operation() :: Operation.t()
  def create_operation do
    %Operation{
      tags: ["apps"],
      summary: "Create an application",
      description: "Create a new application to obtain OAuth2 credentials",
      operationId: "AppController.create",
      requestBody:
        Operation.request_body("Parameters", "application/json", AppCreateRequest, required: true),
      responses: %{
        200 => Operation.response("App", "application/json", AppCreateResponse),
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
      tags: ["apps"],
      summary: "Verify your app works",
      description: "Confirm that the app's OAuth2 credentials work.",
      operationId: "AppController.verify_credentials",
      parameters: [
        Operation.parameter(:authorization, :header, :string, "Bearer <app token>", required: true)
      ],
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
end
