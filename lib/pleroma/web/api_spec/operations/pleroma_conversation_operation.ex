# Pleroma: A lightweight social networking server
# Copyright © 2017-2021 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.ApiSpec.PleromaConversationOperation do
  alias OpenApiSpex.Operation
  alias OpenApiSpex.Schema
  alias Pleroma.Web.ApiSpec.Schemas.Conversation
  alias Pleroma.Web.ApiSpec.Schemas.FlakeID
  alias Pleroma.Web.ApiSpec.StatusOperation

  import Pleroma.Web.ApiSpec.Helpers

  def open_api_operation(action) do
    operation = String.to_existing_atom("#{action}_operation")
    apply(__MODULE__, operation, [])
  end

  def show_operation do
    %Operation{
      tags: ["Conversations"],
      summary: "Conversation",
      parameters: [
        Operation.parameter(:id, :path, :string, "Conversation ID",
          example: "123",
          required: true
        )
      ],
      security: [%{"oAuth" => ["read:statuses"]}],
      operationId: "PleromaAPI.ConversationController.show",
      responses: %{
        200 => Operation.response("Conversation", "application/json", Conversation)
      }
    }
  end

  def statuses_operation do
    %Operation{
      tags: ["Conversations"],
      summary: "Timeline for conversation",
      parameters: [
        Operation.parameter(:id, :path, :string, "Conversation ID",
          example: "123",
          required: true
        )
        | pagination_params()
      ],
      security: [%{"oAuth" => ["read:statuses"]}],
      operationId: "PleromaAPI.ConversationController.statuses",
      responses: %{
        200 =>
          Operation.response(
            "Array of Statuses",
            "application/json",
            StatusOperation.array_of_statuses()
          )
      }
    }
  end

  def update_operation do
    %Operation{
      tags: ["Conversations"],
      summary: "Update conversation",
      description: "Change set of recipients for the conversation.",
      parameters: [
        Operation.parameter(:id, :path, :string, "Conversation ID",
          example: "123",
          required: true
        ),
        Operation.parameter(
          :recipients,
          :query,
          %Schema{type: :array, items: FlakeID},
          "A list of ids of users that should receive posts to this conversation. This will replace the current list of recipients, so submit the full list. The owner of owner of the conversation will always be part of the set of recipients, though.",
          required: true
        )
      ],
      security: [%{"oAuth" => ["write:conversations"]}],
      operationId: "PleromaAPI.ConversationController.update",
      responses: %{
        200 => Operation.response("Conversation", "application/json", Conversation)
      }
    }
  end

  def mark_as_read_operation do
    %Operation{
      tags: ["Conversations"],
      summary: "Marks all conversations as read",
      security: [%{"oAuth" => ["write:conversations"]}],
      operationId: "PleromaAPI.ConversationController.mark_as_read",
      responses: %{
        200 =>
          Operation.response(
            "Array of Conversations that were marked as read",
            "application/json",
            %Schema{
              type: :array,
              items: Conversation,
              example: [Conversation.schema().example]
            }
          )
      }
    }
  end
end
