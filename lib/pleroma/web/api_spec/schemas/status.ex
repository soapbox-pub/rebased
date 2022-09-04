# Pleroma: A lightweight social networking server
# Copyright © 2017-2022 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.ApiSpec.Schemas.Status do
  alias OpenApiSpex.Schema
  alias Pleroma.Web.ApiSpec.Schemas.Account
  alias Pleroma.Web.ApiSpec.Schemas.Attachment
  alias Pleroma.Web.ApiSpec.Schemas.Emoji
  alias Pleroma.Web.ApiSpec.Schemas.FlakeID
  alias Pleroma.Web.ApiSpec.Schemas.Poll
  alias Pleroma.Web.ApiSpec.Schemas.Tag
  alias Pleroma.Web.ApiSpec.Schemas.VisibilityScope

  require OpenApiSpex

  OpenApiSpex.schema(%{
    title: "Status",
    description: "Response schema for a status",
    type: :object,
    properties: %{
      account: %Schema{allOf: [Account], description: "The account that authored this status"},
      application: %Schema{
        description: "The application used to post this status",
        type: :object,
        nullable: true,
        properties: %{
          name: %Schema{type: :string},
          website: %Schema{type: :string, format: :uri}
        }
      },
      bookmarked: %Schema{type: :boolean, description: "Have you bookmarked this status?"},
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
      content: %Schema{type: :string, format: :html, description: "HTML-encoded status content"},
      text: %Schema{
        type: :string,
        description: "Original unformatted content in plain text",
        nullable: true
      },
      created_at: %Schema{
        type: :string,
        format: "date-time",
        description: "The date when this status was created"
      },
      edited_at: %Schema{
        type: :string,
        format: "date-time",
        nullable: true,
        description: "The date when this status was last edited"
      },
      emojis: %Schema{
        type: :array,
        items: Emoji,
        description: "Custom emoji to be used when rendering status content"
      },
      favourited: %Schema{type: :boolean, description: "Have you favourited this status?"},
      favourites_count: %Schema{
        type: :integer,
        description: "How many favourites this status has received"
      },
      id: FlakeID,
      in_reply_to_account_id: %Schema{
        allOf: [FlakeID],
        nullable: true,
        description: "ID of the account being replied to"
      },
      in_reply_to_id: %Schema{
        allOf: [FlakeID],
        nullable: true,
        description: "ID of the status being replied"
      },
      language: %Schema{
        type: :string,
        nullable: true,
        description: "Primary language of this status"
      },
      media_attachments: %Schema{
        type: :array,
        items: Attachment,
        description: "Media that is attached to this status"
      },
      mentions: %Schema{
        type: :array,
        description: "Mentions of users within the status content",
        items: %Schema{
          type: :object,
          properties: %{
            id: %Schema{allOf: [FlakeID], description: "The account id of the mentioned user"},
            acct: %Schema{
              type: :string,
              description:
                "The webfinger acct: URI of the mentioned user. Equivalent to `username` for local users, or `username@domain` for remote users."
            },
            username: %Schema{type: :string, description: "The username of the mentioned user"},
            url: %Schema{
              type: :string,
              format: :uri,
              description: "The location of the mentioned user's profile"
            }
          }
        }
      },
      muted: %Schema{
        type: :boolean,
        description: "Have you muted notifications for this status's conversation?"
      },
      pinned: %Schema{
        type: :boolean,
        description: "Have you pinned this status? Only appears if the status is pinnable."
      },
      pleroma: %Schema{
        type: :object,
        properties: %{
          content: %Schema{
            type: :object,
            additionalProperties: %Schema{type: :string},
            description:
              "A map consisting of alternate representations of the `content` property with the key being it's mimetype. Currently the only alternate representation supported is `text/plain`"
          },
          context: %Schema{
            type: :string,
            description: "The thread identifier the status is associated with"
          },
          conversation_id: %Schema{
            type: :integer,
            deprecated: true,
            description:
              "The ID of the AP context the status is associated with (if any); deprecated, please use `context` instead"
          },
          direct_conversation_id: %Schema{
            type: :integer,
            nullable: true,
            description:
              "The ID of the Mastodon direct message conversation the status is associated with (if any)"
          },
          emoji_reactions: %Schema{
            type: :array,
            description:
              "A list with emoji / reaction maps. Contains no information about the reacting users, for that use the /statuses/:id/reactions endpoint.",
            items: %Schema{
              type: :object,
              properties: %{
                name: %Schema{type: :string},
                count: %Schema{type: :integer},
                me: %Schema{type: :boolean}
              }
            }
          },
          expires_at: %Schema{
            type: :string,
            format: "date-time",
            nullable: true,
            description:
              "A datetime (ISO 8601) that states when the post will expire (be deleted automatically), or empty if the post won't expire"
          },
          in_reply_to_account_acct: %Schema{
            type: :string,
            nullable: true,
            description: "The `acct` property of User entity for replied user (if any)"
          },
          local: %Schema{
            type: :boolean,
            description: "`true` if the post was made on the local instance"
          },
          spoiler_text: %Schema{
            type: :object,
            additionalProperties: %Schema{type: :string},
            description:
              "A map consisting of alternate representations of the `spoiler_text` property with the key being it's mimetype. Currently the only alternate representation supported is `text/plain`."
          },
          thread_muted: %Schema{
            type: :boolean,
            description: "`true` if the thread the post belongs to is muted"
          },
          parent_visible: %Schema{
            type: :boolean,
            description: "`true` if the parent post is visible to the user"
          },
          pinned_at: %Schema{
            type: :string,
            format: "date-time",
            nullable: true,
            description:
              "A datetime (ISO 8601) that states when the post was pinned or `null` if the post is not pinned"
          }
        }
      },
      poll: %Schema{allOf: [Poll], nullable: true, description: "The poll attached to the status"},
      reblog: %Schema{
        allOf: [%OpenApiSpex.Reference{"$ref": "#/components/schemas/Status"}],
        nullable: true,
        description: "The status being reblogged"
      },
      reblogged: %Schema{type: :boolean, description: "Have you boosted this status?"},
      reblogs_count: %Schema{
        type: :integer,
        description: "How many boosts this status has received"
      },
      replies_count: %Schema{
        type: :integer,
        description: "How many replies this status has received"
      },
      sensitive: %Schema{
        type: :boolean,
        description: "Is this status marked as sensitive content?"
      },
      spoiler_text: %Schema{
        type: :string,
        description:
          "Subject or summary line, below which status content is collapsed until expanded"
      },
      tags: %Schema{type: :array, items: Tag},
      uri: %Schema{
        type: :string,
        format: :uri,
        description: "URI of the status used for federation"
      },
      url: %Schema{
        type: :string,
        nullable: true,
        format: :uri,
        description: "A link to the status's HTML representation"
      },
      visibility: %Schema{
        allOf: [VisibilityScope],
        description: "Visibility of this status"
      }
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
        "is_locked" => false,
        "note" => "Tester Number 6",
        "pleroma" => %{
          "background_image" => nil,
          "is_confirmed" => true,
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
            "note" => "",
            "requested" => false,
            "showing_reblogs" => true,
            "subscribing" => false,
            "notifying" => false
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
      "application" => nil,
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
        "context" => "http://localhost:4001/objects/8b4c0c80-6a37-4d2a-b1b9-05a19e3875aa",
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
