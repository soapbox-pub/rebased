# Pleroma: A lightweight social networking server
# Copyright © 2017-2020 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.ApiSpec.ChatOperation do
  alias OpenApiSpex.Operation
  alias OpenApiSpex.Schema

  @spec open_api_operation(atom) :: Operation.t()
  def open_api_operation(action) do
    operation = String.to_existing_atom("#{action}_operation")
    apply(__MODULE__, operation, [])
  end

  def create_operation do
    %Operation{
      tags: ["chat"],
      summary: "Create a chat",
      responses: %{
        200 =>
          Operation.response("Chat", "application/json", %Schema{
            type: :object,
            description: "A created chat is returned",
            properties: %{
              id: %Schema{type: :integer}
            }
          })
      }
    }
  end

  def index_operation do
    %Operation{
      tags: ["chat"],
      summary: "Get a list of chats that you participated in",
      responses: %{
        200 =>
          Operation.response("Chats", "application/json", %Schema{
            type: :array,
            description: "A list of chats",
            items: %Schema{
              type: :object,
              description: "A chat"
            }
          })
      }
    }
  end

  def messages_operation do
    %Operation{
      tags: ["chat"],
      summary: "Get the most recent messages of the chat",
      responses: %{
        200 =>
          Operation.response("Messages", "application/json", %Schema{
            type: :array,
            description: "A list of chat messages",
            items: %Schema{
              type: :object,
              description: "A chat message"
            }
          })
      }
    }
  end

  def post_chat_message_operation do
    %Operation{
      tags: ["chat"],
      summary: "Post a message to the chat",
      responses: %{
        200 =>
          Operation.response("Message", "application/json", %Schema{
            type: :object,
            description: "A chat message"
          })
      }
    }
  end
end
