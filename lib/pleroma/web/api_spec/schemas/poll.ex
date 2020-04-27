# Pleroma: A lightweight social networking server
# Copyright © 2017-2020 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.ApiSpec.Schemas.Poll do
  alias OpenApiSpex.Schema
  alias Pleroma.Web.ApiSpec.Schemas.Emoji
  alias Pleroma.Web.ApiSpec.Schemas.FlakeID

  require OpenApiSpex

  OpenApiSpex.schema(%{
    title: "Poll",
    description: "Response schema for account custom fields",
    type: :object,
    properties: %{
      id: FlakeID,
      expires_at: %Schema{type: :string, format: "date-time"},
      expired: %Schema{type: :boolean},
      multiple: %Schema{type: :boolean},
      votes_count: %Schema{type: :integer},
      voted: %Schema{type: :boolean},
      emojis: %Schema{type: :array, items: Emoji},
      options: %Schema{
        type: :array,
        items: %Schema{
          type: :object,
          properties: %{
            title: %Schema{type: :string},
            votes_count: %Schema{type: :integer}
          }
        }
      }
    }
  })
end
