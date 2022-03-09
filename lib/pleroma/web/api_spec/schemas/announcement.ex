# Pleroma: A lightweight social networking server
# Copyright © 2017-2022 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.ApiSpec.Schemas.Announcement do
  alias OpenApiSpex.Schema
  alias Pleroma.Web.ApiSpec.Schemas.FlakeID

  require OpenApiSpex

  OpenApiSpex.schema(%{
    title: "Announcement",
    description: "Response schema for an announcement",
    type: :object,
    properties: %{
      id: FlakeID,
      content: %Schema{type: :string},
      starts_at: %Schema{
        type: :string,
        format: "date-time",
        nullable: true
      },
      ends_at: %Schema{
        type: :string,
        format: "date-time",
        nullable: true
      },
      all_day: %Schema{type: :boolean},
      published_at: %Schema{type: :string, format: "date-time"},
      updated_at: %Schema{type: :string, format: "date-time"},
      read: %Schema{type: :boolean},
      mentions: %Schema{type: :array},
      statuses: %Schema{type: :array},
      tags: %Schema{type: :array},
      emojis: %Schema{type: :array},
      reactions: %Schema{type: :array},
      pleroma: %Schema{
        type: :object,
        properties: %{
          raw_content: %Schema{type: :string}
        }
      }
    }
  })
end
