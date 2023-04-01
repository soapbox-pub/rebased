# Pleroma: A lightweight social networking server
# Copyright © 2017-2022 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.ApiSpec.StreamingOperation do
  alias OpenApiSpex.Operation
  alias OpenApiSpex.Response
  alias OpenApiSpex.Schema
  alias Pleroma.Web.ApiSpec.Helpers
  alias Pleroma.Web.ApiSpec.NotificationOperation
  alias Pleroma.Web.ApiSpec.Schemas.Chat
  alias Pleroma.Web.ApiSpec.Schemas.Conversation
  alias Pleroma.Web.ApiSpec.Schemas.FlakeID
  alias Pleroma.Web.ApiSpec.Schemas.Status

  @spec open_api_operation(atom) :: Operation.t()
  def open_api_operation(action) do
    operation = String.to_existing_atom("#{action}_operation")
    apply(__MODULE__, operation, [])
  end

  @spec streaming_operation() :: Operation.t()
  def streaming_operation do
    %Operation{
      tags: ["Timelines"],
      summary: "Establish streaming connection",
      description: "Receive statuses in real-time via WebSocket.",
      security: [%{"oAuth" => ["read:statuses", "read:notifications"]}],
      operationId: "WebsocketHandler.streaming",
      parameters: [
        Operation.parameter(:connection, :header, %Schema{type: :string}, "connection header",
          required: true
        ),
        Operation.parameter(:upgrade, :header, %Schema{type: :string}, "upgrade header",
          required: true
        ),
        Operation.parameter(
          :"sec-websocket-key",
          :header,
          %Schema{type: :string},
          "sec-websocket-key header",
          required: true
        ),
        Operation.parameter(
          :"sec-websocket-version",
          :header,
          %Schema{type: :string},
          "sec-websocket-version header",
          required: true
        )
      ],
      responses: %{
        101 => switching_protocols_response(),
        200 =>
          Operation.response(
            "Server-sent events",
            "application/json",
            server_sent_events()
          )
      }
    }
  end

  defp switching_protocols_response do
    %Response{
      description: "Switching protocols",
      headers: %{
        "connection" => %OpenApiSpex.Header{required: true},
        "upgrade" => %OpenApiSpex.Header{required: true},
        "sec-websocket-accept" => %OpenApiSpex.Header{required: true}
      }
    }
  end

  defp server_sent_events do
    %Schema{
      oneOf: [
        update_event(),
        status_update_event(),
        notification_event(),
        chat_update_event(),
        follow_relationships_update_event(),
        conversation_event(),
        delete_event(),
        pleroma_respond_event()
      ]
    }
  end

  defp stream do
    %Schema{
      type: :array,
      title: "Stream",
      description: """
      The stream identifier.
      The first item is the name of the stream. If the stream needs a differentiator, the second item will be the corresponding identifier.
      Currently, for the following stream types, there is a second element in the array:

      - `list`: The second element is the id of the list, as a string.
      - `hashtag`: The second element is the name of the hashtag.
      - `public:remote:media` and `public:remote`: The second element is the domain of the corresponding instance.
      """,
      maxItems: 2,
      minItems: 1,
      items: %Schema{type: :string},
      example: ["hashtag", "mew"]
    }
  end

  defp get_schema(%Schema{} = schema), do: schema
  defp get_schema(schema), do: schema.schema

  defp server_sent_event_helper(name, description, type, payload, opts \\ []) do
    payload_type = opts[:payload_type] || :json
    has_stream = opts[:has_stream] || true

    stream_properties =
      if has_stream do
        %{stream: stream()}
      else
        %{}
      end

    stream_example = if has_stream, do: %{"stream" => get_schema(stream()).example}, else: %{}

    stream_required = if has_stream, do: [:stream], else: []

    %Schema{
      type: :object,
      title: name,
      description: description,
      required: [:event, :payload] ++ stream_required,
      properties:
        %{
          event: %Schema{
            title: "Event type",
            description: "Type of the event.",
            type: :string,
            required: true,
            enum: [type]
          },
          payload:
            if payload_type == :json do
              %Schema{
                title: "Event payload",
                description: "JSON-encoded string of #{get_schema(payload).title}",
                allOf: [payload]
              }
            else
              payload
            end
        }
        |> Map.merge(stream_properties),
      example:
        %{
          "event" => type,
          "payload" => get_schema(payload).example |> Jason.encode!()
        }
        |> Map.merge(stream_example)
    }
  end

  defp update_event do
    server_sent_event_helper("New status", "A newly-posted status.", "update", Status)
  end

  defp status_update_event do
    server_sent_event_helper("Edit", "A status that was just edited", "status.update", Status)
  end

  defp notification_event do
    server_sent_event_helper(
      "Notification",
      "A new notification.",
      "notification",
      NotificationOperation.notification()
    )
  end

  defp follow_relationships_update_event do
    server_sent_event_helper(
      "Follow relationships update",
      "An update to follow relationships.",
      "pleroma:follow_relationships_update",
      %Schema{
        type: :object,
        title: "Follow relationships update",
        required: [:state, :follower, :following],
        properties: %{
          state: %Schema{
            type: :string,
            description: "Follow state of the relationship.",
            enum: ["follow_pending", "follow_accept", "follow_reject", "unfollow"]
          },
          follower: %Schema{
            type: :object,
            description: "Information about the follower.",
            required: [:id, :follower_count, :following_count],
            properties: %{
              id: FlakeID,
              follower_count: %Schema{type: :integer},
              following_count: %Schema{type: :integer}
            }
          },
          following: %Schema{
            type: :object,
            description: "Information about the following person.",
            required: [:id, :follower_count, :following_count],
            properties: %{
              id: FlakeID,
              follower_count: %Schema{type: :integer},
              following_count: %Schema{type: :integer}
            }
          }
        },
        example: %{
          "state" => "follow_pending",
          "follower" => %{
            "id" => "someUser1",
            "follower_count" => 1,
            "following_count" => 1
          },
          "following" => %{
            "id" => "someUser2",
            "follower_count" => 1,
            "following_count" => 1
          }
        }
      }
    )
  end

  defp chat_update_event do
    server_sent_event_helper(
      "Chat update",
      "A new chat message.",
      "pleroma:chat_update",
      Chat
    )
  end

  defp conversation_event do
    server_sent_event_helper(
      "Conversation",
      "An update about a conversation",
      "conversation",
      Conversation
    )
  end

  defp delete_event do
    server_sent_event_helper(
      "Delete",
      "A status that was just deleted.",
      "delete",
      %Schema{
        type: :string,
        title: "Status id",
        description: "Id of the deleted status",
        allOf: [FlakeID],
        example: "some-opaque-id"
      },
      payload_type: :string
    )
  end

  defp pleroma_respond_event do
    server_sent_event_helper(
      "Server response",
      "A response to a client-sent event.",
      "pleroma:respond",
      %Schema{
        type: :object,
        title: "Results",
        required: [:result],
        properties: %{
          result: %Schema{
            type: :string,
            title: "Result of the request",
            enum: ["success", "error", "ignored"]
          },
          error: %Schema{
            type: :string,
            title: "Error code",
            description: "An error identifier. Only appears if `result` is `error`."
          }
        },
        example: %{"result" => "success"}
      }
    )
  end
end
