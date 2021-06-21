# Pleroma: A lightweight social networking server
# Copyright © 2017-2021 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.ApiSpec.ConversationOperation do
  alias OpenApiSpex.Operation
  alias OpenApiSpex.Schema
  alias Pleroma.Web.ApiSpec.Schemas.Conversation
  alias Pleroma.Web.ApiSpec.Schemas.FlakeID

  import Pleroma.Web.ApiSpec.Helpers

  def open_api_operation(action) do
    operation = String.to_existing_atom("#{action}_operation")
    apply(__MODULE__, operation, [])
  end

  def index_operation do
    %Operation{
      tags: ["Conversations"],
      summary: "List of conversations",
      security: [%{"oAuth" => ["read:statuses"]}],
      operationId: "ConversationController.index",
      parameters: [
        Operation.parameter(
          :recipients,
          :query,
          %Schema{type: :array, items: FlakeID},
          "Only return conversations with the given recipients (a list of user ids)"
        )
        | pagination_params()
      ],
      responses: %{
        200 =>
          Operation.response("Array of Conversation", "application/json", %Schema{
            type: :array,
            items: Conversation,
            example: [Conversation.schema().example]
          })
      }
    }
  end

  def mark_as_read_operation do
    %Operation{
      tags: ["Conversations"],
      summary: "Mark conversation as read",
      operationId: "ConversationController.mark_as_read",
      parameters: [id_param()],
      security: [%{"oAuth" => ["write:conversations"]}],
      responses: %{
        200 => Operation.response("Conversation", "application/json", Conversation)
      }
    }
  end

  def delete_operation do
    %Operation{
      tags: ["Conversations"],
      summary: "Remove conversation",
      operationId: "ConversationController.delete",
      parameters: [id_param()],
      security: [%{"oAuth" => ["write:conversations"]}],
      responses: %{
        200 => empty_object_response()
      }
    }
  end

  def id_param do
    Operation.parameter(:id, :path, :string, "Conversation ID",
      example: "123",
      required: true
    )
  end
end
