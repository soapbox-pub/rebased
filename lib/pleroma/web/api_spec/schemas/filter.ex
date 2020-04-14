# Pleroma: A lightweight social networking server
# Copyright © 2017-2020 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.ApiSpec.Schemas.Filter do
  alias OpenApiSpex.Schema
  require OpenApiSpex

  OpenApiSpex.schema(%{
    title: "Filter",
    type: :object,
    properties: %{
      id: %Schema{type: :string},
      phrase: %Schema{type: :string, description: "The text to be filtered"},
      context: %Schema{
        type: :array,
        items: %Schema{type: :string, enum: ["home", "notifications", "public", "thread"]},
        description: "The contexts in which the filter should be applied."
      },
      expires_at: %Schema{
        type: :string,
        format: :"date-time",
        description:
          "When the filter should no longer be applied. String (ISO 8601 Datetime), or null if the filter does not expire.",
        nullable: true
      },
      irreversible: %Schema{
        type: :boolean,
        description:
          "Should matching entities in home and notifications be dropped by the server?"
      },
      whole_word: %Schema{
        type: :boolean,
        description: "Should the filter consider word boundaries?"
      }
    },
    example: %{
      "id" => "5580",
      "phrase" => "@twitter.com",
      "context" => [
        "home",
        "notifications",
        "public",
        "thread"
      ],
      "whole_word" => false,
      "expires_at" => nil,
      "irreversible" => true
    }
  })
end
