# Pleroma: A lightweight social networking server
# Copyright © 2017-2020 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.ApiSpec.Schemas.Status do
  alias OpenApiSpex.Schema
  alias Pleroma.Web.ApiSpec.Schemas.Account
  alias Pleroma.Web.ApiSpec.Schemas.Attachment
  alias Pleroma.Web.ApiSpec.Schemas.Emoji
  alias Pleroma.Web.ApiSpec.Schemas.FlakeID
  alias Pleroma.Web.ApiSpec.Schemas.Poll
  alias Pleroma.Web.ApiSpec.Schemas.VisibilityScope

  require OpenApiSpex

  OpenApiSpex.schema(%{
    title: "Status",
    description: "Response schema for a status",
    type: :object,
    properties: %{
      account: Account,
      application: %Schema{
        type: :object,
        properties: %{
          name: %Schema{type: :string},
          website: %Schema{type: :string, nullable: true, format: :uri}
        }
      },
      bookmarked: %Schema{type: :boolean},
      card: %Schema{
        type: :object,
        nullable: true,
        properties: %{
          type: %Schema{type: :string, enum: ["link", "photo", "video", "rich"]},
          provider_name: %Schema{type: :string, nullable: true},
          provider_url: %Schema{type: :string, format: :uri},
          url: %Schema{type: :string, format: :uri},
          image: %Schema{type: :string, nullable: true, format: :uri},
          title: %Schema{type: :string},
          description: %Schema{type: :string}
        }
      },
      content: %Schema{type: :string, format: :html},
      created_at: %Schema{type: :string, format: "date-time"},
      emojis: %Schema{type: :array, items: Emoji},
      favourited: %Schema{type: :boolean},
      favourites_count: %Schema{type: :integer},
      id: FlakeID,
      in_reply_to_account_id: %Schema{type: :string, nullable: true},
      in_reply_to_id: %Schema{type: :string, nullable: true},
      language: %Schema{type: :string, nullable: true},
      media_attachments: %Schema{
        type: :array,
        items: Attachment
      },
      mentions: %Schema{
        type: :array,
        items: %Schema{
          type: :object,
          properties: %{
            id: %Schema{type: :string},
            acct: %Schema{type: :string},
            username: %Schema{type: :string},
            url: %Schema{type: :string, format: :uri}
          }
        }
      },
      muted: %Schema{type: :boolean},
      pinned: %Schema{type: :boolean},
      pleroma: %Schema{
        type: :object,
        properties: %{
          content: %Schema{type: :object, additionalProperties: %Schema{type: :string}},
          conversation_id: %Schema{type: :integer},
          direct_conversation_id: %Schema{
            type: :integer,
            nullable: true,
            description:
              "The ID of the Mastodon direct message conversation the status is associated with (if any)"
          },
          emoji_reactions: %Schema{
            type: :array,
            items: %Schema{
              type: :object,
              properties: %{
                name: %Schema{type: :string},
                count: %Schema{type: :integer},
                me: %Schema{type: :boolean}
              }
            }
          },
          expires_at: %Schema{type: :string, format: "date-time", nullable: true},
          in_reply_to_account_acct: %Schema{type: :string, nullable: true},
          local: %Schema{type: :boolean},
          spoiler_text: %Schema{type: :object, additionalProperties: %Schema{type: :string}},
          thread_muted: %Schema{type: :boolean}
        }
      },
      poll: %Schema{type: Poll, nullable: true},
      reblog: %Schema{
        allOf: [%OpenApiSpex.Reference{"$ref": "#/components/schemas/Status"}],
        nullable: true
      },
      reblogged: %Schema{type: :boolean},
      reblogs_count: %Schema{type: :integer},
      replies_count: %Schema{type: :integer},
      sensitive: %Schema{type: :boolean},
      spoiler_text: %Schema{type: :string},
      tags: %Schema{
        type: :array,
        items: %Schema{
          type: :object,
          properties: %{
            name: %Schema{type: :string},
            url: %Schema{type: :string, format: :uri}
          }
        }
      },
      uri: %Schema{type: :string, format: :uri},
      url: %Schema{type: :string, nullable: true, format: :uri},
      visibility: VisibilityScope
    },
    example: %{
      "account" => %{
        "acct" => "nick6",
        "avatar" => "http://localhost:4001/images/avi.png",
        "avatar_static" => "http://localhost:4001/images/avi.png",
        "bot" => false,
        "created_at" => "2020-04-07T19:48:51.000Z",
        "display_name" => "Test テスト User 6",
        "emojis" => [],
        "fields" => [],
        "followers_count" => 1,
        "following_count" => 0,
        "header" => "http://localhost:4001/images/banner.png",
        "header_static" => "http://localhost:4001/images/banner.png",
        "id" => "9toJCsKN7SmSf3aj5c",
        "locked" => false,
        "note" => "Tester Number 6",
        "pleroma" => %{
          "background_image" => nil,
          "confirmation_pending" => false,
          "hide_favorites" => true,
          "hide_followers" => false,
          "hide_followers_count" => false,
          "hide_follows" => false,
          "hide_follows_count" => false,
          "is_admin" => false,
          "is_moderator" => false,
          "relationship" => %{
            "blocked_by" => false,
            "blocking" => false,
            "domain_blocking" => false,
            "endorsed" => false,
            "followed_by" => false,
            "following" => true,
            "id" => "9toJCsKN7SmSf3aj5c",
            "muting" => false,
            "muting_notifications" => false,
            "requested" => false,
            "showing_reblogs" => true,
            "subscribing" => false
          },
          "skip_thread_containment" => false,
          "tags" => []
        },
        "source" => %{
          "fields" => [],
          "note" => "Tester Number 6",
          "pleroma" => %{"actor_type" => "Person", "discoverable" => false},
          "sensitive" => false
        },
        "statuses_count" => 1,
        "url" => "http://localhost:4001/users/nick6",
        "username" => "nick6"
      },
      "application" => %{"name" => "Web", "website" => nil},
      "bookmarked" => false,
      "card" => nil,
      "content" => "foobar",
      "created_at" => "2020-04-07T19:48:51.000Z",
      "emojis" => [],
      "favourited" => false,
      "favourites_count" => 0,
      "id" => "9toJCu5YZW7O7gfvH6",
      "in_reply_to_account_id" => nil,
      "in_reply_to_id" => nil,
      "language" => nil,
      "media_attachments" => [],
      "mentions" => [],
      "muted" => false,
      "pinned" => false,
      "pleroma" => %{
        "content" => %{"text/plain" => "foobar"},
        "conversation_id" => 345_972,
        "direct_conversation_id" => nil,
        "emoji_reactions" => [],
        "expires_at" => nil,
        "in_reply_to_account_acct" => nil,
        "local" => true,
        "spoiler_text" => %{"text/plain" => ""},
        "thread_muted" => false
      },
      "poll" => nil,
      "reblog" => nil,
      "reblogged" => false,
      "reblogs_count" => 0,
      "replies_count" => 0,
      "sensitive" => false,
      "spoiler_text" => "",
      "tags" => [],
      "uri" => "http://localhost:4001/objects/0f5dad44-0e9e-4610-b377-a2631e499190",
      "url" => "http://localhost:4001/notice/9toJCu5YZW7O7gfvH6",
      "visibility" => "private"
    }
  })
end
