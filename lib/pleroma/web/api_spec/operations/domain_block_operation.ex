# Pleroma: A lightweight social networking server
# Copyright © 2017-2020 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.ApiSpec.DomainBlockOperation do
  alias OpenApiSpex.Operation
  alias OpenApiSpex.Schema
  alias Pleroma.Web.ApiSpec.Helpers
  alias Pleroma.Web.ApiSpec.Schemas.DomainBlockRequest
  alias Pleroma.Web.ApiSpec.Schemas.DomainBlocksResponse

  def open_api_operation(action) do
    operation = String.to_existing_atom("#{action}_operation")
    apply(__MODULE__, operation, [])
  end

  def index_operation do
    %Operation{
      tags: ["domain_blocks"],
      summary: "Fetch domain blocks",
      description: "View domains the user has blocked.",
      security: [%{"oAuth" => ["follow", "read:blocks"]}],
      operationId: "DomainBlockController.index",
      responses: %{
        200 => Operation.response("Domain blocks", "application/json", DomainBlocksResponse)
      }
    }
  end

  def create_operation do
    %Operation{
      tags: ["domain_blocks"],
      summary: "Block a domain",
      description: """
      Block a domain to:

      - hide all public posts from it
      - hide all notifications from it
      - remove all followers from it
      - prevent following new users from it (but does not remove existing follows)
      """,
      operationId: "DomainBlockController.create",
      requestBody: Helpers.request_body("Parameters", DomainBlockRequest, required: true),
      security: [%{"oAuth" => ["follow", "write:blocks"]}],
      responses: %{
        200 => Operation.response("Empty object", "application/json", %Schema{type: :object})
      }
    }
  end

  def delete_operation do
    %Operation{
      tags: ["domain_blocks"],
      summary: "Unblock a domain",
      description: "Remove a domain block, if it exists in the user's array of blocked domains.",
      operationId: "DomainBlockController.delete",
      requestBody: Helpers.request_body("Parameters", DomainBlockRequest, required: true),
      security: [%{"oAuth" => ["follow", "write:blocks"]}],
      responses: %{
        200 => Operation.response("Empty object", "application/json", %Schema{type: :object})
      }
    }
  end
end
