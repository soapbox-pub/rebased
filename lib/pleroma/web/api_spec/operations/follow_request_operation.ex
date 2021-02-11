# Pleroma: A lightweight social networking server
# Copyright © 2017-2021 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.ApiSpec.FollowRequestOperation do
  alias OpenApiSpex.Operation
  alias OpenApiSpex.Schema
  alias Pleroma.Web.ApiSpec.Schemas.Account
  alias Pleroma.Web.ApiSpec.Schemas.AccountRelationship

  def open_api_operation(action) do
    operation = String.to_existing_atom("#{action}_operation")
    apply(__MODULE__, operation, [])
  end

  def index_operation do
    %Operation{
      tags: ["Follow requests"],
      summary: "Retrieve follow requests",
      security: [%{"oAuth" => ["read:follows", "follow"]}],
      operationId: "FollowRequestController.index",
      responses: %{
        200 =>
          Operation.response("Array of Account", "application/json", %Schema{
            type: :array,
            items: Account,
            example: [Account.schema().example]
          })
      }
    }
  end

  def authorize_operation do
    %Operation{
      tags: ["Follow requests"],
      summary: "Accept follow request",
      operationId: "FollowRequestController.authorize",
      parameters: [id_param()],
      security: [%{"oAuth" => ["follow", "write:follows"]}],
      responses: %{
        200 => Operation.response("Relationship", "application/json", AccountRelationship)
      }
    }
  end

  def reject_operation do
    %Operation{
      tags: ["Follow requests"],
      summary: "Reject follow request",
      operationId: "FollowRequestController.reject",
      parameters: [id_param()],
      security: [%{"oAuth" => ["follow", "write:follows"]}],
      responses: %{
        200 => Operation.response("Relationship", "application/json", AccountRelationship)
      }
    }
  end

  defp id_param do
    Operation.parameter(:id, :path, :string, "Conversation ID",
      example: "123",
      required: true
    )
  end
end
