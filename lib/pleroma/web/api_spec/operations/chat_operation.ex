# Pleroma: A lightweight social networking server
# Copyright © 2017-2021 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.ApiSpec.ChatOperation do
  alias OpenApiSpex.Operation
  alias OpenApiSpex.Schema
  alias Pleroma.Web.ApiSpec.Schemas.ApiError
  alias Pleroma.Web.ApiSpec.Schemas.BooleanLike
  alias Pleroma.Web.ApiSpec.Schemas.Chat
  alias Pleroma.Web.ApiSpec.Schemas.ChatMessage

  import Pleroma.Web.ApiSpec.Helpers

  @spec open_api_operation(atom) :: Operation.t()
  def open_api_operation(action) do
    operation = String.to_existing_atom("#{action}_operation")
    apply(__MODULE__, operation, [])
  end

  def mark_as_read_operation do
    %Operation{
      tags: ["Chats"],
      summary: "Mark all messages in the chat as read",
      operationId: "ChatController.mark_as_read",
      parameters: [Operation.parameter(:id, :path, :string, "The ID of the Chat")],
      requestBody: request_body("Parameters", mark_as_read()),
      responses: %{
        200 =>
          Operation.response(
            "The updated chat",
            "application/json",
            Chat
          )
      },
      security: [
        %{
          "oAuth" => ["write:chats"]
        }
      ]
    }
  end

  def mark_message_as_read_operation do
    %Operation{
      tags: ["Chats"],
      summary: "Mark a message as read",
      operationId: "ChatController.mark_message_as_read",
      parameters: [
        Operation.parameter(:id, :path, :string, "The ID of the Chat"),
        Operation.parameter(:message_id, :path, :string, "The ID of the message")
      ],
      responses: %{
        200 =>
          Operation.response(
            "The read ChatMessage",
            "application/json",
            ChatMessage
          )
      },
      security: [
        %{
          "oAuth" => ["write:chats"]
        }
      ]
    }
  end

  def show_operation do
    %Operation{
      tags: ["Chats"],
      summary: "Retrieve a chat",
      operationId: "ChatController.show",
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
          "oAuth" => ["read"]
        }
      ]
    }
  end

  def create_operation do
    %Operation{
      tags: ["Chats"],
      summary: "Create a chat",
      operationId: "ChatController.create",
      parameters: [
        Operation.parameter(
          :id,
          :path,
          :string,
          "The account id of the recipient of this chat",
          required: true,
          example: "someflakeid"
        )
      ],
      responses: %{
        200 =>
          Operation.response(
            "The created or existing chat",
            "application/json",
            Chat
          )
      },
      security: [
        %{
          "oAuth" => ["write:chats"]
        }
      ]
    }
  end

  def index_operation do
    %Operation{
      tags: ["Chats"],
      summary: "Retrieve list of chats (unpaginated)",
      deprecated: true,
      description:
        "Deprecated due to no support for pagination. Using [/api/v2/pleroma/chats](#operation/ChatController.index2) instead is recommended.",
      operationId: "ChatController.index",
      parameters: [
        Operation.parameter(:with_muted, :query, BooleanLike, "Include chats from muted users")
      ],
      responses: %{
        200 => Operation.response("The chats of the user", "application/json", chats_response())
      },
      security: [
        %{
          "oAuth" => ["read:chats"]
        }
      ]
    }
  end

  def index2_operation do
    %Operation{
      tags: ["Chats"],
      summary: "Retrieve list of chats",
      operationId: "ChatController.index2",
      parameters: [
        Operation.parameter(:with_muted, :query, BooleanLike, "Include chats from muted users")
        | pagination_params()
      ],
      responses: %{
        200 => Operation.response("The chats of the user", "application/json", chats_response())
      },
      security: [
        %{
          "oAuth" => ["read:chats"]
        }
      ]
    }
  end

  def messages_operation do
    %Operation{
      tags: ["Chats"],
      summary: "Retrieve chat's messages",
      operationId: "ChatController.messages",
      parameters:
        [Operation.parameter(:id, :path, :string, "The ID of the Chat")] ++
          pagination_params(),
      responses: %{
        200 =>
          Operation.response(
            "The messages in the chat",
            "application/json",
            chat_messages_response()
          ),
        404 => Operation.response("Not Found", "application/json", ApiError)
      },
      security: [
        %{
          "oAuth" => ["read:chats"]
        }
      ]
    }
  end

  def post_chat_message_operation do
    %Operation{
      tags: ["Chats"],
      summary: "Post a message to the chat",
      operationId: "ChatController.post_chat_message",
      parameters: [
        Operation.parameter(:id, :path, :string, "The ID of the Chat")
      ],
      requestBody: request_body("Parameters", chat_message_create()),
      responses: %{
        200 =>
          Operation.response(
            "The newly created ChatMessage",
            "application/json",
            ChatMessage
          ),
        400 => Operation.response("Bad Request", "application/json", ApiError),
        422 => Operation.response("MRF Rejection", "application/json", ApiError)
      },
      security: [
        %{
          "oAuth" => ["write:chats"]
        }
      ]
    }
  end

  def delete_message_operation do
    %Operation{
      tags: ["Chats"],
      summary: "Delete message",
      operationId: "ChatController.delete_message",
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
          "oAuth" => ["write:chats"]
        }
      ]
    }
  end

  def chats_response do
    %Schema{
      title: "ChatsResponse",
      description: "Response schema for multiple Chats",
      type: :array,
      items: Chat,
      example: [
        %{
          "account" => %{
            "pleroma" => %{
              "is_admin" => false,
              "is_confirmed" => true,
              "hide_followers_count" => false,
              "is_moderator" => false,
              "hide_favorites" => true,
              "ap_id" => "https://dontbulling.me/users/lain",
              "hide_follows_count" => false,
              "hide_follows" => false,
              "background_image" => nil,
              "skip_thread_containment" => false,
              "hide_followers" => false,
              "relationship" => %{},
              "tags" => []
            },
            "avatar" =>
              "https://dontbulling.me/media/065a4dd3c6740dab13ff9c71ec7d240bb9f8be9205c9e7467fb2202117da1e32.jpg",
            "following_count" => 0,
            "header_static" => "https://originalpatchou.li/images/banner.png",
            "source" => %{
              "sensitive" => false,
              "note" => "lain",
              "pleroma" => %{
                "discoverable" => false,
                "actor_type" => "Person"
              },
              "fields" => []
            },
            "statuses_count" => 1,
            "locked" => false,
            "created_at" => "2020-04-16T13:40:15.000Z",
            "display_name" => "lain",
            "fields" => [],
            "acct" => "lain@dontbulling.me",
            "id" => "9u6Qw6TAZANpqokMkK",
            "emojis" => [],
            "avatar_static" =>
              "https://dontbulling.me/media/065a4dd3c6740dab13ff9c71ec7d240bb9f8be9205c9e7467fb2202117da1e32.jpg",
            "username" => "lain",
            "followers_count" => 0,
            "header" => "https://originalpatchou.li/images/banner.png",
            "bot" => false,
            "note" => "lain",
            "url" => "https://dontbulling.me/users/lain"
          },
          "id" => "1",
          "unread" => 2
        }
      ]
    }
  end

  def chat_messages_response do
    %Schema{
      title: "ChatMessagesResponse",
      description: "Response schema for multiple ChatMessages",
      type: :array,
      items: ChatMessage,
      example: [
        %{
          "emojis" => [
            %{
              "static_url" => "https://dontbulling.me/emoji/Firefox.gif",
              "visible_in_picker" => false,
              "shortcode" => "firefox",
              "url" => "https://dontbulling.me/emoji/Firefox.gif"
            }
          ],
          "created_at" => "2020-04-21T15:11:46.000Z",
          "content" => "Check this out :firefox:",
          "id" => "13",
          "chat_id" => "1",
          "account_id" => "someflakeid",
          "unread" => false
        },
        %{
          "account_id" => "someflakeid",
          "content" => "Whats' up?",
          "id" => "12",
          "chat_id" => "1",
          "emojis" => [],
          "created_at" => "2020-04-21T15:06:45.000Z",
          "unread" => false
        }
      ]
    }
  end

  def chat_message_create do
    %Schema{
      title: "ChatMessageCreateRequest",
      description: "POST body for creating an chat message",
      type: :object,
      properties: %{
        content: %Schema{
          type: :string,
          description: "The content of your message. Optional if media_id is present"
        },
        media_id: %Schema{type: :string, description: "The id of an upload"}
      },
      example: %{
        "content" => "Hey wanna buy feet pics?",
        "media_id" => "134234"
      }
    }
  end

  def mark_as_read do
    %Schema{
      title: "MarkAsReadRequest",
      description: "POST body for marking a number of chat messages as read",
      type: :object,
      required: [:last_read_id],
      properties: %{
        last_read_id: %Schema{
          type: :string,
          description: "The content of your message."
        }
      },
      example: %{
        "last_read_id" => "abcdef12456"
      }
    }
  end
end
