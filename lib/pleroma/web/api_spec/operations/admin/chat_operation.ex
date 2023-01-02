# Pleroma: A lightweight social networking server
# Copyright © 2017-2022 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.ApiSpec.Admin.ChatOperation do
  alias OpenApiSpex.Operation
  alias Pleroma.Web.ApiSpec.Schemas.Chat
  alias Pleroma.Web.ApiSpec.Schemas.ChatMessage

  import Pleroma.Web.ApiSpec.Helpers

  def open_api_operation(action) do
    operation = String.to_existing_atom("#{action}_operation")
    apply(__MODULE__, operation, [])
  end

  def delete_message_operation do
    %Operation{
      tags: ["Chat administration"],
      summary: "Delete an individual chat message",
      operationId: "AdminAPI.ChatController.delete_message",
      parameters: [
        Operation.parameter(:id, :path, :string, "The ID of the Chat"),
        Operation.parameter(:message_id, :path, :string, "The ID of the message")
      ],
      responses: %{
        200 =>
          Operation.response(
            "The deleted ChatMessage",
            "application/json",
            ChatMessage
          )
      },
      security: [
        %{
          "oAuth" => ["admin:write:chats"]
        }
      ]
    }
  end

  def messages_operation do
    %Operation{
      tags: ["Chat administration"],
      summary: "Get chat's messages",
      operationId: "AdminAPI.ChatController.messages",
      parameters:
        [Operation.parameter(:id, :path, :string, "The ID of the Chat")] ++
          pagination_params(),
      responses: %{
        200 =>
          Operation.response(
            "The messages in the chat",
            "application/json",
            Pleroma.Web.ApiSpec.ChatOperation.chat_messages_response()
          )
      },
      security: [
        %{
          "oAuth" => ["admin:read:chats"]
        }
      ]
    }
  end

  def show_operation do
    %Operation{
      tags: ["Chat administration"],
      summary: "Create a chat",
      operationId: "AdminAPI.ChatController.show",
      parameters: [
        Operation.parameter(
          :id,
          :path,
          :string,
          "The id of the chat",
          required: true,
          example: "1234"
        )
      ],
      responses: %{
        200 =>
          Operation.response(
            "The existing chat",
            "application/json",
            Chat
          )
      },
      security: [
        %{
          "oAuth" => ["admin:read"]
        }
      ]
    }
  end
end
