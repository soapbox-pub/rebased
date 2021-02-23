# Pleroma: A lightweight social networking server
# Copyright © 2017-2021 Pleroma Authors <https://pleroma.social/>
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
      tags: ["Relays"],
      summary: "Retrieve a list of relays",
      operationId: "AdminAPI.RelayController.index",
      security: [%{"oAuth" => ["admin:read"]}],
      parameters: admin_api_params(),
      responses: %{
        200 =>
          Operation.response("Response", "application/json", %Schema{
            type: :object,
            properties: %{
              relays: %Schema{
                type: :array,
                items: relay()
              }
            }
          })
      }
    }
  end

  def follow_operation do
    %Operation{
      tags: ["Relays"],
      summary: "Follow a relay",
      operationId: "AdminAPI.RelayController.follow",
      security: [%{"oAuth" => ["admin:write:follows"]}],
      parameters: admin_api_params(),
      requestBody: request_body("Parameters", relay_url()),
      responses: %{
        200 => Operation.response("Status", "application/json", relay())
      }
    }
  end

  def unfollow_operation do
    %Operation{
      tags: ["Relays"],
      summary: "Unfollow a relay",
      operationId: "AdminAPI.RelayController.unfollow",
      security: [%{"oAuth" => ["admin:write:follows"]}],
      parameters: admin_api_params(),
      requestBody: request_body("Parameters", relay_unfollow()),
      responses: %{
        200 =>
          Operation.response("Status", "application/json", %Schema{
            type: :string,
            example: "http://mastodon.example.org/users/admin"
          })
      }
    }
  end

  defp relay do
    %Schema{
      type: :object,
      properties: %{
        actor: %Schema{
          type: :string,
          example: "https://example.com/relay"
        },
        followed_back: %Schema{
          type: :boolean,
          description: "Is relay followed back by this actor?"
        }
      }
    }
  end

  defp relay_url do
    %Schema{
      type: :object,
      properties: %{
        relay_url: %Schema{type: :string, format: :uri}
      }
    }
  end

  defp relay_unfollow do
    %Schema{
      type: :object,
      properties: %{
        relay_url: %Schema{type: :string, format: :uri},
        force: %Schema{type: :boolean, default: false}
      }
    }
  end
end
