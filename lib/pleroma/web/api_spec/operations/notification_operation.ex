# Pleroma: A lightweight social networking server
# Copyright © 2017-2022 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.ApiSpec.NotificationOperation do
  alias OpenApiSpex.Operation
  alias OpenApiSpex.Operation
  alias OpenApiSpex.Schema
  alias Pleroma.Web.ApiSpec.Schemas.Account
  alias Pleroma.Web.ApiSpec.Schemas.ApiError
  alias Pleroma.Web.ApiSpec.Schemas.BooleanLike
  alias Pleroma.Web.ApiSpec.Schemas.Status
  alias Pleroma.Web.ApiSpec.Schemas.VisibilityScope

  import Pleroma.Web.ApiSpec.Helpers

  def open_api_operation(action) do
    operation = String.to_existing_atom("#{action}_operation")
    apply(__MODULE__, operation, [])
  end

  def index_operation do
    %Operation{
      tags: ["Notifications"],
      summary: "Retrieve a list of notifications",
      description:
        "Notifications concerning the user. This API returns Link headers containing links to the next/previous page. However, the links can also be constructed dynamically using query params and `id` values.",
      operationId: "NotificationController.index",
      security: [%{"oAuth" => ["read:notifications"]}],
      parameters:
        [
          Operation.parameter(
            :exclude_types,
            :query,
            %Schema{type: :array, items: notification_type()},
            "Array of types to exclude"
          ),
          Operation.parameter(
            :account_id,
            :query,
            %Schema{type: :string},
            "Return only notifications received from this account"
          ),
          Operation.parameter(
            :exclude_visibilities,
            :query,
            %Schema{type: :array, items: VisibilityScope},
            "Exclude the notifications for activities with the given visibilities"
          ),
          Operation.parameter(
            :include_types,
            :query,
            %Schema{type: :array, items: notification_type()},
            "Deprecated, use `types` instead"
          ),
          Operation.parameter(
            :types,
            :query,
            %Schema{type: :array, items: notification_type()},
            "Include the notifications for activities with the given types"
          ),
          Operation.parameter(
            :with_muted,
            :query,
            BooleanLike,
            "Include the notifications from muted users"
          )
        ] ++ pagination_params(),
      responses: %{
        200 =>
          Operation.response("Array of notifications", "application/json", %Schema{
            type: :array,
            items: notification()
          }),
        404 => Operation.response("Error", "application/json", ApiError)
      }
    }
  end

  def show_operation do
    %Operation{
      tags: ["Notifications"],
      summary: "Retrieve a notification",
      description: "View information about a notification with a given ID.",
      operationId: "NotificationController.show",
      security: [%{"oAuth" => ["read:notifications"]}],
      parameters: [id_param()],
      responses: %{
        200 => Operation.response("Notification", "application/json", notification())
      }
    }
  end

  def clear_operation do
    %Operation{
      tags: ["Notifications"],
      summary: "Dismiss all notifications",
      description: "Clear all notifications from the server.",
      operationId: "NotificationController.clear",
      security: [%{"oAuth" => ["write:notifications"]}],
      responses: %{200 => empty_object_response()}
    }
  end

  def dismiss_operation do
    %Operation{
      tags: ["Notifications"],
      summary: "Dismiss a notification",
      description: "Clear a single notification from the server.",
      operationId: "NotificationController.dismiss",
      parameters: [id_param()],
      security: [%{"oAuth" => ["write:notifications"]}],
      responses: %{200 => empty_object_response()}
    }
  end

  def dismiss_via_body_operation do
    %Operation{
      tags: ["Notifications"],
      summary: "Dismiss a single notification",
      deprecated: true,
      description: "Clear a single notification from the server.",
      operationId: "NotificationController.dismiss_via_body",
      requestBody:
        request_body(
          "Parameters",
          %Schema{type: :object, properties: %{id: %Schema{type: :string}}},
          required: true
        ),
      security: [%{"oAuth" => ["write:notifications"]}],
      responses: %{200 => empty_object_response()}
    }
  end

  def destroy_multiple_operation do
    %Operation{
      tags: ["Notifications"],
      summary: "Dismiss multiple notifications",
      operationId: "NotificationController.destroy_multiple",
      security: [%{"oAuth" => ["write:notifications"]}],
      parameters: [
        Operation.parameter(
          :ids,
          :query,
          %Schema{type: :array, items: %Schema{type: :string}},
          "Array of notification IDs to dismiss",
          required: true
        )
      ],
      responses: %{200 => empty_object_response()}
    }
  end

  def notification do
    %Schema{
      title: "Notification",
      description: "Response schema for a notification",
      type: :object,
      properties: %{
        id: %Schema{type: :string},
        type: notification_type(),
        created_at: %Schema{type: :string, format: :"date-time"},
        account: %Schema{
          allOf: [Account],
          description: "The account that performed the action that generated the notification."
        },
        status: %Schema{
          allOf: [Status],
          description:
            "Status that was the object of the notification, e.g. in mentions, reblogs, favourites, or polls.",
          nullable: true
        },
        pleroma: %Schema{
          type: :object,
          properties: %{
            is_seen: %Schema{type: :boolean},
            is_muted: %Schema{type: :boolean}
          }
        }
      },
      example: %{
        "id" => "34975861",
        "type" => "mention",
        "created_at" => "2019-11-23T07:49:02.064Z",
        "account" => Account.schema().example,
        "status" => Status.schema().example,
        "pleroma" => %{"is_seen" => false, "is_muted" => false}
      }
    }
  end

  defp notification_type do
    %Schema{
      type: :string,
      enum: [
        "follow",
        "favourite",
        "reblog",
        "mention",
        "pleroma:emoji_reaction",
        "pleroma:chat_mention",
        "pleroma:report",
        "move",
        "follow_request",
        "poll"
      ],
      description: """
      The type of event that resulted in the notification.

      - `follow` - Someone followed you
      - `mention` - Someone mentioned you in their status
      - `reblog` - Someone boosted one of your statuses
      - `favourite` - Someone favourited one of your statuses
      - `poll` - A poll you have voted in or created has ended
      - `move` - Someone moved their account
      - `pleroma:emoji_reaction` - Someone reacted with emoji to your status
      - `pleroma:chat_mention` - Someone mentioned you in a chat message
      - `pleroma:report` - Someone was reported
      """
    }
  end

  defp id_param do
    Operation.parameter(:id, :path, :string, "Notification ID",
      example: "123",
      required: true
    )
  end
end
