# Pleroma: A lightweight social networking server
# Copyright © 2017-2020 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.ApiSpec.Schemas.FilterUpdateRequest do
  alias OpenApiSpex.Schema
  require OpenApiSpex

  OpenApiSpex.schema(%{
    title: "FilterUpdateRequest",
    type: :object,
    properties: %{
      phrase: %Schema{type: :string, description: "The text to be filtered"},
      context: %Schema{
        type: :array,
        items: %Schema{type: :string, enum: ["home", "notifications", "public", "thread"]},
        description:
          "Array of enumerable strings `home`, `notifications`, `public`, `thread`. At least one context must be specified."
      },
      irreversible: %Schema{
        type: :bolean,
        description:
          "Should the server irreversibly drop matching entities from home and notifications?"
      },
      whole_word: %Schema{type: :bolean, description: "Consider word boundaries?", default: true}
      # TODO: probably should implement filter expiration
      # expires_in: %Schema{
      #   type: :string,
      #   format: :"date-time",
      #   description:
      #     "ISO 8601 Datetime for when the filter expires. Otherwise,
      #  null for a filter that doesn't expire."
      # }
    },
    required: [:phrase, :context],
    example: %{
      "phrase" => "knights",
      "context" => ["home"]
    }
  })
end
