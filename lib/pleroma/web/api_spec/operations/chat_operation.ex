# Pleroma: A lightweight social networking server
# Copyright © 2017-2020 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.ApiSpec.ChatOperation do
  alias OpenApiSpex.Operation
  alias Pleroma.Web.ApiSpec.Helpers
  alias Pleroma.Web.ApiSpec.Schemas.ChatMessageCreateRequest
  alias Pleroma.Web.ApiSpec.Schemas.ChatMessageResponse
  alias Pleroma.Web.ApiSpec.Schemas.ChatMessagesResponse
  alias Pleroma.Web.ApiSpec.Schemas.ChatResponse
  alias Pleroma.Web.ApiSpec.Schemas.ChatsResponse

  @spec open_api_operation(atom) :: Operation.t()
  def open_api_operation(action) do
    operation = String.to_existing_atom("#{action}_operation")
    apply(__MODULE__, operation, [])
  end

  def create_operation do
    %Operation{
      tags: ["chat"],
      summary: "Create a chat",
      operationId: "ChatController.create",
      parameters: [
        Operation.parameter(
          :ap_id,
          :path,
          :string,
          "The ActivityPub id of the recipient of this chat.",
          required: true,
          example: "https://lain.com/users/lain"
        )
      ],
      responses: %{
        200 =>
          Operation.response("The created or existing chat", "application/json", ChatResponse)
      },
      security: [
        %{
          "oAuth" => ["write"]
        }
      ]
    }
  end

  def index_operation do
    %Operation{
      tags: ["chat"],
      summary: "Get a list of chats that you participated in",
      operationId: "ChatController.index",
      parameters: [
        Operation.parameter(:limit, :query, :integer, "How many results to return", example: 20),
        Operation.parameter(:min_id, :query, :string, "Return only chats after this id"),
        Operation.parameter(:max_id, :query, :string, "Return only chats before this id")
      ],
      responses: %{
        200 => Operation.response("The chats of the user", "application/json", ChatsResponse)
      },
      security: [
        %{
          "oAuth" => ["read"]
        }
      ]
    }
  end

  def messages_operation do
    %Operation{
      tags: ["chat"],
      summary: "Get the most recent messages of the chat",
      operationId: "ChatController.messages",
      parameters: [
        Operation.parameter(:id, :path, :string, "The ID of the Chat"),
        Operation.parameter(:limit, :query, :integer, "How many results to return", example: 20),
        Operation.parameter(:min_id, :query, :string, "Return only messages after this id"),
        Operation.parameter(:max_id, :query, :string, "Return only messages before this id")
      ],
      responses: %{
        200 =>
          Operation.response("The messages in the chat", "application/json", ChatMessagesResponse)
      },
      security: [
        %{
          "oAuth" => ["read"]
        }
      ]
    }
  end

  def post_chat_message_operation do
    %Operation{
      tags: ["chat"],
      summary: "Post a message to the chat",
      operationId: "ChatController.post_chat_message",
      parameters: [
        Operation.parameter(:id, :path, :string, "The ID of the Chat")
      ],
      requestBody: Helpers.request_body("Parameters", ChatMessageCreateRequest, required: true),
      responses: %{
        200 =>
          Operation.response(
            "The newly created ChatMessage",
            "application/json",
            ChatMessageResponse
          )
      },
      security: [
        %{
          "oAuth" => ["write"]
        }
      ]
    }
  end
end
