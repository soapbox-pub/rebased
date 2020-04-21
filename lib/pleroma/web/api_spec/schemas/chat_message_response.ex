# Pleroma: A lightweight social networking server
# Copyright © 2017-2020 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.ApiSpec.Schemas.ChatMessageResponse do
  alias OpenApiSpex.Schema

  require OpenApiSpex

  OpenApiSpex.schema(%{
    title: "ChatMessageResponse",
    description: "Response schema for a ChatMessage",
    type: :object,
    properties: %{
      id: %Schema{type: :string},
      actor: %Schema{type: :string, description: "The ActivityPub id of the actor"},
      chat_id: %Schema{type: :string},
      content: %Schema{type: :string},
      created_at: %Schema{type: :string, format: :datetime},
      emojis: %Schema{type: :array}
    },
    example: %{
      "actor" => "https://dontbulling.me/users/lain",
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
      "id" => "14"
    }
  })
end
