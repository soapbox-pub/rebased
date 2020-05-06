# Pleroma: A lightweight social networking server
# Copyright © 2017-2020 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.ApiSpec.Schemas.ChatMessage do
  alias OpenApiSpex.Schema

  require OpenApiSpex

  OpenApiSpex.schema(%{
    title: "ChatMessage",
    description: "Response schema for a ChatMessage",
    type: :object,
    properties: %{
      id: %Schema{type: :string},
      account_id: %Schema{type: :string, description: "The Mastodon API id of the actor"},
      chat_id: %Schema{type: :string},
      content: %Schema{type: :string},
      created_at: %Schema{type: :string, format: :"date-time"},
      emojis: %Schema{type: :array},
      attachment: %Schema{type: :object, nullable: true}
    },
    example: %{
      "account_id" => "someflakeid",
      "chat_id" => "1",
      "content" => "hey you again",
      "created_at" => "2020-04-21T15:06:45.000Z",
      "emojis" => [
        %{
          "static_url" => "https://dontbulling.me/emoji/Firefox.gif",
          "visible_in_picker" => false,
          "shortcode" => "firefox",
          "url" => "https://dontbulling.me/emoji/Firefox.gif"
        }
      ],
      "id" => "14",
      "attachment" => nil
    }
  })
end
