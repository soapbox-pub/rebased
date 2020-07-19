# Pleroma: A lightweight social networking server
# Copyright © 2017-2020 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.ApiSpec.Admin.RelayOperation do
  alias OpenApiSpex.Operation
  alias OpenApiSpex.Schema

  import Pleroma.Web.ApiSpec.Helpers

  def open_api_operation(action) do
    operation = String.to_existing_atom("#{action}_operation")
    apply(__MODULE__, operation, [])
  end

  def index_operation do
    %Operation{
      tags: ["Admin", "Relays"],
      summary: "List Relays",
      operationId: "AdminAPI.RelayController.index",
      security: [%{"oAuth" => ["read"]}],
      parameters: admin_api_params(),
      responses: %{
        200 =>
          Operation.response("Response", "application/json", %Schema{
            type: :object,
            properties: %{
              relays: %Schema{
                type: :array,
                items: %Schema{type: :string},
                example: ["lain.com", "mstdn.io"]
              }
            }
          })
      }
    }
  end

  def follow_operation do
    %Operation{
      tags: ["Admin", "Relays"],
      summary: "Follow a Relay",
      operationId: "AdminAPI.RelayController.follow",
      security: [%{"oAuth" => ["write:follows"]}],
      parameters: admin_api_params(),
      requestBody:
        request_body("Parameters", %Schema{
          type: :object,
          properties: %{
            relay_url: %Schema{type: :string, format: :uri}
          }
        }),
      responses: %{
        200 =>
          Operation.response("Status", "application/json", %Schema{
            type: :string,
            example: "http://mastodon.example.org/users/admin"
          })
      }
    }
  end

  def unfollow_operation do
    %Operation{
      tags: ["Admin", "Relays"],
      summary: "Unfollow a Relay",
      operationId: "AdminAPI.RelayController.unfollow",
      security: [%{"oAuth" => ["write:follows"]}],
      parameters: admin_api_params(),
      requestBody:
        request_body("Parameters", %Schema{
          type: :object,
          properties: %{
            relay_url: %Schema{type: :string, format: :uri}
          }
        }),
      responses: %{
        200 =>
          Operation.response("Status", "application/json", %Schema{
            type: :string,
            example: "http://mastodon.example.org/users/admin"
          })
      }
    }
  end
end
