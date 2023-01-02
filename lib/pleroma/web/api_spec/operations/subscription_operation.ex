# Pleroma: A lightweight social networking server
# Copyright © 2017-2022 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.ApiSpec.SubscriptionOperation do
  alias OpenApiSpex.Operation
  alias OpenApiSpex.Schema
  alias Pleroma.Web.ApiSpec.Helpers
  alias Pleroma.Web.ApiSpec.Schemas.ApiError
  alias Pleroma.Web.ApiSpec.Schemas.BooleanLike
  alias Pleroma.Web.ApiSpec.Schemas.PushSubscription

  def open_api_operation(action) do
    operation = String.to_existing_atom("#{action}_operation")
    apply(__MODULE__, operation, [])
  end

  def create_operation do
    %Operation{
      tags: ["Push subscriptions"],
      summary: "Subscribe to push notifications",
      description:
        "Add a Web Push API subscription to receive notifications. Each access token can have one push subscription. If you create a new subscription, the old subscription is deleted.",
      operationId: "SubscriptionController.create",
      security: [%{"oAuth" => ["push"]}],
      requestBody: Helpers.request_body("Parameters", create_request(), required: true),
      responses: %{
        200 => Operation.response("Push subscription", "application/json", PushSubscription),
        400 => Operation.response("Error", "application/json", ApiError),
        403 => Operation.response("Error", "application/json", ApiError)
      }
    }
  end

  def show_operation do
    %Operation{
      tags: ["Push subscriptions"],
      summary: "Get current subscription",
      description: "View the PushSubscription currently associated with this access token.",
      operationId: "SubscriptionController.show",
      security: [%{"oAuth" => ["push"]}],
      responses: %{
        200 => Operation.response("Push subscription", "application/json", PushSubscription),
        403 => Operation.response("Error", "application/json", ApiError),
        404 => Operation.response("Error", "application/json", ApiError)
      }
    }
  end

  def update_operation do
    %Operation{
      tags: ["Push subscriptions"],
      summary: "Change types of notifications",
      description:
        "Updates the current push subscription. Only the data part can be updated. To change fundamentals, a new subscription must be created instead.",
      operationId: "SubscriptionController.update",
      security: [%{"oAuth" => ["push"]}],
      requestBody: Helpers.request_body("Parameters", update_request(), required: true),
      responses: %{
        200 => Operation.response("Push subscription", "application/json", PushSubscription),
        403 => Operation.response("Error", "application/json", ApiError)
      }
    }
  end

  def delete_operation do
    %Operation{
      tags: ["Push subscriptions"],
      summary: "Remove current subscription",
      description: "Removes the current Web Push API subscription.",
      operationId: "SubscriptionController.delete",
      security: [%{"oAuth" => ["push"]}],
      responses: %{
        200 => Operation.response("Empty object", "application/json", %Schema{type: :object}),
        403 => Operation.response("Error", "application/json", ApiError),
        404 => Operation.response("Error", "application/json", ApiError)
      }
    }
  end

  defp create_request do
    %Schema{
      title: "SubscriptionCreateRequest",
      description: "POST body for creating a push subscription",
      type: :object,
      properties: %{
        subscription: %Schema{
          type: :object,
          properties: %{
            endpoint: %Schema{
              type: :string,
              description: "Endpoint URL that is called when a notification event occurs."
            },
            keys: %Schema{
              type: :object,
              properties: %{
                p256dh: %Schema{
                  type: :string,
                  description:
                    "User agent public key. Base64 encoded string of public key of ECDH key using `prime256v1` curve."
                },
                auth: %Schema{
                  type: :string,
                  description: "Auth secret. Base64 encoded string of 16 bytes of random data."
                }
              },
              required: [:p256dh, :auth]
            }
          },
          required: [:endpoint, :keys]
        },
        data: %Schema{
          nullable: true,
          type: :object,
          properties: %{
            alerts: %Schema{
              nullable: true,
              type: :object,
              properties: %{
                follow: %Schema{
                  allOf: [BooleanLike],
                  nullable: true,
                  description: "Receive follow notifications?"
                },
                favourite: %Schema{
                  allOf: [BooleanLike],
                  nullable: true,
                  description: "Receive favourite notifications?"
                },
                reblog: %Schema{
                  allOf: [BooleanLike],
                  nullable: true,
                  description: "Receive reblog notifications?"
                },
                mention: %Schema{
                  allOf: [BooleanLike],
                  nullable: true,
                  description: "Receive mention notifications?"
                },
                poll: %Schema{
                  allOf: [BooleanLike],
                  nullable: true,
                  description: "Receive poll notifications?"
                },
                "pleroma:chat_mention": %Schema{
                  allOf: [BooleanLike],
                  nullable: true,
                  description: "Receive chat notifications?"
                },
                "pleroma:emoji_reaction": %Schema{
                  allOf: [BooleanLike],
                  nullable: true,
                  description: "Receive emoji reaction notifications?"
                }
              }
            }
          }
        }
      },
      required: [:subscription],
      example: %{
        "subscription" => %{
          "endpoint" => "https://example.com/example/1234",
          "keys" => %{
            "auth" => "8eDyX_uCN0XRhSbY5hs7Hg==",
            "p256dh" =>
              "BCIWgsnyXDv1VkhqL2P7YRBvdeuDnlwAPT2guNhdIoW3IP7GmHh1SMKPLxRf7x8vJy6ZFK3ol2ohgn_-0yP7QQA="
          }
        },
        "data" => %{
          "alerts" => %{
            "follow" => true,
            "mention" => true,
            "poll" => false
          }
        }
      }
    }
  end

  defp update_request do
    %Schema{
      title: "SubscriptionUpdateRequest",
      type: :object,
      properties: %{
        data: %Schema{
          nullable: true,
          type: :object,
          properties: %{
            alerts: %Schema{
              nullable: true,
              type: :object,
              properties: %{
                follow: %Schema{
                  allOf: [BooleanLike],
                  nullable: true,
                  description: "Receive follow notifications?"
                },
                favourite: %Schema{
                  allOf: [BooleanLike],
                  nullable: true,
                  description: "Receive favourite notifications?"
                },
                reblog: %Schema{
                  allOf: [BooleanLike],
                  nullable: true,
                  description: "Receive reblog notifications?"
                },
                mention: %Schema{
                  allOf: [BooleanLike],
                  nullable: true,
                  description: "Receive mention notifications?"
                },
                poll: %Schema{
                  allOf: [BooleanLike],
                  nullable: true,
                  description: "Receive poll notifications?"
                },
                "pleroma:chat_mention": %Schema{
                  allOf: [BooleanLike],
                  nullable: true,
                  description: "Receive chat notifications?"
                },
                "pleroma:emoji_reaction": %Schema{
                  allOf: [BooleanLike],
                  nullable: true,
                  description: "Receive emoji reaction notifications?"
                }
              }
            }
          }
        }
      },
      example: %{
        "data" => %{
          "alerts" => %{
            "follow" => true,
            "favourite" => true,
            "reblog" => true,
            "mention" => true,
            "poll" => true
          }
        }
      }
    }
  end
end
