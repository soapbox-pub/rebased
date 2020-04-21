# Pleroma: A lightweight social networking server
# Copyright © 2017-2020 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.ApiSpec.Schemas.ChatMessagesResponse do
  alias Pleroma.Web.ApiSpec.Schemas.ChatMessageResponse

  require OpenApiSpex

  OpenApiSpex.schema(%{
    title: "ChatMessagesResponse",
    description: "Response schema for multiple ChatMessages",
    type: :array,
    items: ChatMessageResponse,
    example: [
      %{
        "emojis" => [
          %{
            "static_url" => "https://dontbulling.me/emoji/Firefox.gif",
            "visible_in_picker" => false,
            "shortcode" => "firefox",
            "url" => "https://dontbulling.me/emoji/Firefox.gif"
          }
        ],
        "created_at" => "2020-04-21T15:11:46.000Z",
        "content" => "Check this out :firefox:",
        "id" => "13",
        "chat_id" => "1",
        "actor" => "https://dontbulling.me/users/lain"
      },
      %{
        "actor" => "https://dontbulling.me/users/lain",
        "content" => "Whats' up?",
        "id" => "12",
        "chat_id" => "1",
        "emojis" => [],
        "created_at" => "2020-04-21T15:06:45.000Z"
      }
    ]
  })
end
