# Pleroma: A lightweight social networking server
# Copyright © 2017-2022 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.ApiSpec.Schemas.Poll do
  alias OpenApiSpex.Schema
  alias Pleroma.Web.ApiSpec.Schemas.Emoji
  alias Pleroma.Web.ApiSpec.Schemas.FlakeID

  require OpenApiSpex

  OpenApiSpex.schema(%{
    title: "Poll",
    description: "Represents a poll attached to a status",
    type: :object,
    properties: %{
      id: FlakeID,
      expires_at: %Schema{
        type: :string,
        format: :"date-time",
        nullable: true,
        description: "When the poll ends"
      },
      expired: %Schema{type: :boolean, description: "Is the poll currently expired?"},
      multiple: %Schema{
        type: :boolean,
        description: "Does the poll allow multiple-choice answers?"
      },
      votes_count: %Schema{
        type: :integer,
        description: "How many votes have been received. Number."
      },
      voters_count: %Schema{
        type: :integer,
        description: "How many unique accounts have voted. Number."
      },
      voted: %Schema{
        type: :boolean,
        nullable: true,
        description:
          "When called with a user token, has the authorized user voted? Boolean, or null if no current user."
      },
      emojis: %Schema{
        type: :array,
        items: Emoji,
        description: "Custom emoji to be used for rendering poll options."
      },
      options: %Schema{
        type: :array,
        items: %Schema{
          title: "PollOption",
          type: :object,
          properties: %{
            title: %Schema{type: :string},
            votes_count: %Schema{type: :integer}
          }
        },
        description: "Possible answers for the poll."
      }
    },
    example: %{
      id: "34830",
      expires_at: "2019-12-05T04:05:08.302Z",
      expired: true,
      multiple: false,
      votes_count: 10,
      voters_count: 10,
      voted: true,
      own_votes: [
        1
      ],
      options: [
        %{
          title: "accept",
          votes_count: 6
        },
        %{
          title: "deny",
          votes_count: 4
        }
      ],
      emojis: []
    }
  })
end
