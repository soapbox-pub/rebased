# Pleroma: A lightweight social networking server
# Copyright © 2017-2022 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.ApiSpec.Schemas.Emoji do
  alias OpenApiSpex.Schema

  require OpenApiSpex

  OpenApiSpex.schema(%{
    title: "Emoji",
    description: "Response schema for an emoji",
    type: :object,
    properties: %{
      shortcode: %Schema{type: :string},
      url: %Schema{type: :string, format: :uri},
      static_url: %Schema{type: :string, format: :uri},
      visible_in_picker: %Schema{type: :boolean}
    },
    example: %{
      "shortcode" => "fatyoshi",
      "url" =>
        "https://files.mastodon.social/custom_emojis/images/000/023/920/original/e57ecb623faa0dc9.png",
      "static_url" =>
        "https://files.mastodon.social/custom_emojis/images/000/023/920/static/e57ecb623faa0dc9.png",
      "visible_in_picker" => true
    }
  })
end
