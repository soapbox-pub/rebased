# Pleroma: A lightweight social networking server
# Copyright © 2017-2022 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.ApiSpec.Schemas.Event do
  alias OpenApiSpex.Schema

  require OpenApiSpex

  OpenApiSpex.schema(%{
    title: "Event",
    description: "Represents an event attached to a status",
    type: :object,
    properties: %{
      name: %Schema{
        type: :string,
        description: "Name of the event"
      },
      start_time: %Schema{
        type: :string,
        format: :"date-time",
        description: "Start time",
        nullable: true
      },
      end_time: %Schema{
        type: :string,
        format: :"date-time",
        description: "End time",
        nullable: true
      },
      join_mode: %Schema{
        type: :string,
        description: "Who can join the event"
      },
      participants_count: %Schema{
        type: :integer,
        description: "Event participants count",
        nullable: true
      },
      participation_request_count: %Schema{
        type: :integer,
        description: "Event participation requests count",
        nullable: true
      },
      location: %Schema{
        type: :object,
        description: "Location where the event takes part",
        properties: %{
          name: %Schema{
            type: :string,
            description: "Object name",
            nullable: true
          },
          url: %Schema{
            type: :string,
            description: "Object URL",
            nullable: true
          },
          longitude: %Schema{
            type: :number,
            description: "Object vertical coordinate",
            nullable: true
          },
          latitude: %Schema{
            type: :number,
            description: "Object horizontal coordinate",
            nullable: true
          },
          street: %Schema{
            type: :string,
            description: "Object street",
            nullable: true
          },
          postal_code: %Schema{
            type: :string,
            description: "Object postal code",
            nullable: true
          },
          locality: %Schema{
            type: :string,
            description: "Object locality",
            nullable: true
          },
          region: %Schema{
            type: :string,
            description: "Object region",
            nullable: true
          },
          country: %Schema{
            type: :string,
            description: "Object country",
            nullable: true
          }
        },
        nullable: true
      },
      join_state: %Schema{
        type: :string,
        description: "Have you joined the event?",
        enum: ["pending", "reject", "accept"],
        nullable: true
      }
    },
    example: %{
      name: "Example event",
      start_time: "2022-02-21T22:00:00.000Z",
      end_time: "2022-02-21T23:00:00.000Z",
      join_mode: "free",
      participants_count: 0
    }
  })
end
