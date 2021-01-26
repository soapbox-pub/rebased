# Pleroma: A lightweight social networking server
# Copyright © 2017-2021 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.ApiSpec.Schemas.Chat do
  alias OpenApiSpex.Schema
  alias Pleroma.Web.ApiSpec.Schemas.ChatMessage

  require OpenApiSpex

  OpenApiSpex.schema(%{
    title: "Chat",
    description: "Response schema for a Chat",
    type: :object,
    properties: %{
      id: %Schema{type: :string},
      account: %Schema{type: :object},
      unread: %Schema{type: :integer},
      last_message: ChatMessage,
      updated_at: %Schema{type: :string, format: :"date-time"}
    },
    example: %{
      "account" => %{
        "pleroma" => %{
          "is_admin" => false,
          "is_confirmed" => true,
          "hide_followers_count" => false,
          "is_moderator" => false,
          "hide_favorites" => true,
          "ap_id" => "https://dontbulling.me/users/lain",
          "hide_follows_count" => false,
          "hide_follows" => false,
          "background_image" => nil,
          "skip_thread_containment" => false,
          "hide_followers" => false,
          "relationship" => %{},
          "tags" => []
        },
        "avatar" =>
          "https://dontbulling.me/media/065a4dd3c6740dab13ff9c71ec7d240bb9f8be9205c9e7467fb2202117da1e32.jpg",
        "following_count" => 0,
        "header_static" => "https://originalpatchou.li/images/banner.png",
        "source" => %{
          "sensitive" => false,
          "note" => "lain",
          "pleroma" => %{
            "discoverable" => false,
            "actor_type" => "Person"
          },
          "fields" => []
        },
        "statuses_count" => 1,
        "is_locked" => false,
        "created_at" => "2020-04-16T13:40:15.000Z",
        "display_name" => "lain",
        "fields" => [],
        "acct" => "lain@dontbulling.me",
        "id" => "9u6Qw6TAZANpqokMkK",
        "emojis" => [],
        "avatar_static" =>
          "https://dontbulling.me/media/065a4dd3c6740dab13ff9c71ec7d240bb9f8be9205c9e7467fb2202117da1e32.jpg",
        "username" => "lain",
        "followers_count" => 0,
        "header" => "https://originalpatchou.li/images/banner.png",
        "bot" => false,
        "note" => "lain",
        "url" => "https://dontbulling.me/users/lain"
      },
      "id" => "1",
      "unread" => 2,
      "last_message" => ChatMessage.schema().example(),
      "updated_at" => "2020-04-21T15:06:45.000Z"
    }
  })
end
