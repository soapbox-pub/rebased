# Pleroma: A lightweight social networking server
# Copyright © 2017-2021 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.ApiSpec.Schemas.ChatMessage do
  alias OpenApiSpex.Schema
  alias Pleroma.Web.ApiSpec.Schemas.Emoji

  require OpenApiSpex

  OpenApiSpex.schema(%{
    title: "ChatMessage",
    description: "Response schema for a ChatMessage",
    nullable: true,
    type: :object,
    properties: %{
      id: %Schema{type: :string},
      account_id: %Schema{type: :string, description: "The Mastodon API id of the actor"},
      chat_id: %Schema{type: :string},
      content: %Schema{type: :string, nullable: true},
      created_at: %Schema{type: :string, format: :"date-time"},
      emojis: %Schema{type: :array, items: Emoji},
      attachment: %Schema{type: :object, nullable: true},
      card: %Schema{
        type: :object,
        nullable: true,
        description: "Preview card for links included within status content",
        required: [:url, :title, :description, :type],
        properties: %{
          type: %Schema{
            type: :string,
            enum: ["link", "photo", "video", "rich"],
            description: "The type of the preview card"
          },
          provider_name: %Schema{
            type: :string,
            nullable: true,
            description: "The provider of the original resource"
          },
          provider_url: %Schema{
            type: :string,
            format: :uri,
            description: "A link to the provider of the original resource"
          },
          url: %Schema{type: :string, format: :uri, description: "Location of linked resource"},
          image: %Schema{
            type: :string,
            nullable: true,
            format: :uri,
            description: "Preview thumbnail"
          },
          title: %Schema{type: :string, description: "Title of linked resource"},
          description: %Schema{type: :string, description: "Description of preview"}
        }
      },
      unread: %Schema{type: :boolean, description: "Whether a message has been marked as read."}
    },
    example: %{
      "account_id" => "someflakeid",
      "chat_id" => "1",
      "content" => "hey you again",
      "created_at" => "2020-04-21T15:06:45.000Z",
      "card" => nil,
      "emojis" => [
        %{
          "static_url" => "https://dontbulling.me/emoji/Firefox.gif",
          "visible_in_picker" => false,
          "shortcode" => "firefox",
          "url" => "https://dontbulling.me/emoji/Firefox.gif"
        }
      ],
      "id" => "14",
      "attachment" => nil,
      "unread" => false
    }
  })
end
