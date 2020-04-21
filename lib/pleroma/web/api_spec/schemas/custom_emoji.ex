# Pleroma: A lightweight social networking server
# Copyright © 2017-2020 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.ApiSpec.Schemas.CustomEmoji do
  alias OpenApiSpex.Schema

  require OpenApiSpex

  OpenApiSpex.schema(%{
    title: "CustomEmoji",
    description: "Response schema for an CustomEmoji",
    type: :object,
    properties: %{
      shortcode: %Schema{type: :string},
      url: %Schema{type: :string},
      static_url: %Schema{type: :string},
      visible_in_picker: %Schema{type: :boolean},
      category: %Schema{type: :string},
      tags: %Schema{type: :array}
    },
    example: %{
      "shortcode" => "aaaa",
      "url" => "https://files.mastodon.social/custom_emojis/images/000/007/118/original/aaaa.png",
      "static_url" =>
        "https://files.mastodon.social/custom_emojis/images/000/007/118/static/aaaa.png",
      "visible_in_picker" => true
    }
  })
end
