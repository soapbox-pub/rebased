# Pleroma: A lightweight social networking server
# Copyright © 2017-2020 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.ApiSpec.PleromaOperation do
  alias OpenApiSpex.Operation
  alias OpenApiSpex.Schema
  alias Pleroma.Web.ApiSpec.Schemas.Account
  alias Pleroma.Web.ApiSpec.Schemas.ApiError
  alias Pleroma.Web.ApiSpec.Schemas.FlakeID
  alias Pleroma.Web.ApiSpec.Schemas.Status
  alias Pleroma.Web.ApiSpec.Schemas.Conversation
  alias Pleroma.Web.ApiSpec.StatusOperation
  alias Pleroma.Web.ApiSpec.NotificationOperation

  import Pleroma.Web.ApiSpec.Helpers

  def open_api_operation(action) do
    operation = String.to_existing_atom("#{action}_operation")
    apply(__MODULE__, operation, [])
  end

  def emoji_reactions_by_operation do
    %Operation{
      tags: ["Emoji Reactions"],
      summary:
        "Get an object of emoji to account mappings with accounts that reacted to the post",
      parameters: [
        Operation.parameter(:id, :path, FlakeID, "Status ID", required: true),
        Operation.parameter(:emoji, :path, :string, "Filter by a single unicode emoji",
          required: false
        )
      ],
      security: [%{"oAuth" => ["read:statuses"]}],
      operationId: "PleromaController.emoji_reactions_by",
      responses: %{
        200 => array_of_reactions_response()
      }
    }
  end

  def react_with_emoji_operation do
    %Operation{
      tags: ["Emoji Reactions"],
      summary: "React to a post with a unicode emoji",
      parameters: [
        Operation.parameter(:id, :path, FlakeID, "Status ID", required: true),
        Operation.parameter(:emoji, :path, :string, "A single character unicode emoji",
          required: true
        )
      ],
      security: [%{"oAuth" => ["write:statuses"]}],
      operationId: "PleromaController.react_with_emoji",
      responses: %{
        200 => Operation.response("Status", "application/json", Status)
      }
    }
  end

  def unreact_with_emoji_operation do
    %Operation{
      tags: ["Emoji Reactions"],
      summary: "Remove a reaction to a post with a unicode emoji",
      parameters: [
        Operation.parameter(:id, :path, FlakeID, "Status ID", required: true),
        Operation.parameter(:emoji, :path, :string, "A single character unicode emoji",
          required: true
        )
      ],
      security: [%{"oAuth" => ["write:statuses"]}],
      operationId: "PleromaController.unreact_with_emoji",
      responses: %{
        200 => Operation.response("Status", "application/json", Status)
      }
    }
  end

  defp array_of_reactions_response do
    Operation.response("Array of Emoji Reactions", "application/json", %Schema{
      type: :array,
      items: emoji_reaction(),
      example: [emoji_reaction().example]
    })
  end

  defp emoji_reaction do
    %Schema{
      title: "EmojiReaction",
      type: :object,
      properties: %{
        name: %Schema{type: :string, description: "Emoji"},
        count: %Schema{type: :integer, description: "Count of reactions with this emoji"},
        me: %Schema{type: :boolean, description: "Did I react with this emoji?"},
        accounts: %Schema{
          type: :array,
          items: Account,
          description: "Array of accounts reacted with this emoji"
        }
      },
      example: %{
        "name" => "😱",
        "count" => 1,
        "me" => false,
        "accounts" => [Account.schema().example]
      }
    }
  end

  def conversation_operation do
    %Operation{
      tags: ["Conversations"],
      summary: "The conversation with the given ID",
      parameters: [
        Operation.parameter(:id, :path, :string, "Conversation ID",
          example: "123",
          required: true
        )
      ],
      security: [%{"oAuth" => ["read:statuses"]}],
      operationId: "PleromaController.conversation",
      responses: %{
        200 => Operation.response("Conversation", "application/json", Conversation)
      }
    }
  end

  def conversation_statuses_operation do
    %Operation{
      tags: ["Conversations"],
      summary: "Timeline for a given conversation",
      parameters: [
        Operation.parameter(:id, :path, :string, "Conversation ID",
          example: "123",
          required: true
        )
        | pagination_params()
      ],
      security: [%{"oAuth" => ["read:statuses"]}],
      operationId: "PleromaController.conversation_statuses",
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

  def update_conversation_operation do
    %Operation{
      tags: ["Conversations"],
      summary: "Update a conversation. Used to change the set of recipients.",
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
      operationId: "PleromaController.update_conversation",
      responses: %{
        200 => Operation.response("Conversation", "application/json", Conversation)
      }
    }
  end

  def mark_conversations_as_read_operation do
    %Operation{
      tags: ["Conversations"],
      summary: "Marks all user's conversations as read",
      security: [%{"oAuth" => ["write:conversations"]}],
      operationId: "PleromaController.mark_conversations_as_read",
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

  def mark_notifications_as_read_operation do
    %Operation{
      tags: ["Notifications"],
      summary: "Mark notifications as read. Query parameters are mutually exclusive.",
      parameters: [
        Operation.parameter(:id, :query, :string, "A single notification ID to read"),
        Operation.parameter(:max_id, :query, :string, "Read all notifications up to this id")
      ],
      security: [%{"oAuth" => ["write:notifications"]}],
      operationId: "PleromaController.mark_notifications_as_read",
      responses: %{
        200 =>
          Operation.response(
            "A Notification or array of Motifications",
            "application/json",
            %Schema{
              anyOf: [
                %Schema{type: :array, items: NotificationOperation.notification()},
                NotificationOperation.notification()
              ]
            }
          ),
        400 => Operation.response("Bad Request", "application/json", ApiError)
      }
    }
  end
end
