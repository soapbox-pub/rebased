# Pleroma: A lightweight social networking server
# Copyright © 2017-2020 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.ApiSpec.Schemas.CustomEmojisResponse do
  alias Pleroma.Web.ApiSpec.Schemas.CustomEmoji

  require OpenApiSpex

  OpenApiSpex.schema(%{
    title: "CustomEmojisResponse",
    description: "Response schema for custom emojis",
    type: :array,
    items: CustomEmoji,
    example: [
      %{
        "category" => "Fun",
        "shortcode" => "blank",
        "static_url" => "https://lain.com/emoji/blank.png",
        "tags" => ["Fun"],
        "url" => "https://lain.com/emoji/blank.png",
        "visible_in_picker" => true
      },
      %{
        "category" => "Gif,Fun",
        "shortcode" => "firefox",
        "static_url" => "https://lain.com/emoji/Firefox.gif",
        "tags" => ["Gif", "Fun"],
        "url" => "https://lain.com/emoji/Firefox.gif",
        "visible_in_picker" => true
      },
      %{
        "category" => "pack:mixed",
        "shortcode" => "sadcat",
        "static_url" => "https://lain.com/emoji/mixed/sadcat.png",
        "tags" => ["pack:mixed"],
        "url" => "https://lain.com/emoji/mixed/sadcat.png",
        "visible_in_picker" => true
      }
    ]
  })
end
