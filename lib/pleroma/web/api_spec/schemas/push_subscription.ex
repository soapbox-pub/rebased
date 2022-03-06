# Pleroma: A lightweight social networking server
# Copyright © 2017-2022 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.ApiSpec.Schemas.PushSubscription do
  alias OpenApiSpex.Schema

  require OpenApiSpex

  OpenApiSpex.schema(%{
    title: "PushSubscription",
    description: "Response schema for a push subscription",
    type: :object,
    properties: %{
      id: %Schema{
        anyOf: [%Schema{type: :string}, %Schema{type: :integer}],
        description: "The id of the push subscription in the database."
      },
      endpoint: %Schema{type: :string, description: "Where push alerts will be sent to."},
      server_key: %Schema{type: :string, description: "The streaming server's VAPID key."},
      alerts: %Schema{
        type: :object,
        description: "Which alerts should be delivered to the endpoint.",
        properties: %{
          follow: %Schema{
            type: :boolean,
            description: "Receive a push notification when someone has followed you?"
          },
          favourite: %Schema{
            type: :boolean,
            description:
              "Receive a push notification when a status you created has been favourited by someone else?"
          },
          reblog: %Schema{
            type: :boolean,
            description:
              "Receive a push notification when a status you created has been boosted by someone else?"
          },
          mention: %Schema{
            type: :boolean,
            description:
              "Receive a push notification when someone else has mentioned you in a status?"
          },
          poll: %Schema{
            type: :boolean,
            description:
              "Receive a push notification when a poll you voted in or created has ended? "
          }
        }
      }
    },
    example: %{
      "id" => "328_183",
      "endpoint" => "https://yourdomain.example/listener",
      "alerts" => %{
        "follow" => true,
        "favourite" => true,
        "reblog" => true,
        "mention" => true,
        "poll" => true
      },
      "server_key" =>
        "BCk-QqERU0q-CfYZjcuB6lnyyOYfJ2AifKqfeGIm7Z-HiTU5T9eTG5GxVA0_OH5mMlI4UkkDTpaZwozy0TzdZ2M="
    }
  })
end
