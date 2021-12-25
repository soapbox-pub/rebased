# Pleroma: A lightweight social networking server
# Copyright © 2017-2021 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.ApiSpec.Schemas.Account do
  alias OpenApiSpex.Schema
  alias Pleroma.Web.ApiSpec.Schemas.AccountField
  alias Pleroma.Web.ApiSpec.Schemas.AccountRelationship
  alias Pleroma.Web.ApiSpec.Schemas.ActorType
  alias Pleroma.Web.ApiSpec.Schemas.Emoji
  alias Pleroma.Web.ApiSpec.Schemas.FlakeID
  alias Pleroma.Web.ApiSpec.Schemas.VisibilityScope

  require OpenApiSpex

  OpenApiSpex.schema(%{
    title: "Account",
    description: "Response schema for an account",
    type: :object,
    properties: %{
      acct: %Schema{type: :string},
      avatar_static: %Schema{type: :string, format: :uri},
      avatar: %Schema{type: :string, format: :uri},
      bot: %Schema{type: :boolean},
      created_at: %Schema{type: :string, format: "date-time"},
      display_name: %Schema{type: :string},
      emojis: %Schema{type: :array, items: Emoji},
      fields: %Schema{type: :array, items: AccountField},
      follow_requests_count: %Schema{type: :integer},
      followers_count: %Schema{type: :integer},
      following_count: %Schema{type: :integer},
      header_static: %Schema{type: :string, format: :uri},
      header: %Schema{type: :string, format: :uri},
      id: FlakeID,
      locked: %Schema{type: :boolean},
      note: %Schema{type: :string, format: :html},
      statuses_count: %Schema{type: :integer},
      url: %Schema{type: :string, format: :uri},
      username: %Schema{type: :string},
      pleroma: %Schema{
        type: :object,
        properties: %{
          ap_id: %Schema{type: :string},
          also_known_as: %Schema{type: :array, items: %Schema{type: :string}},
          allow_following_move: %Schema{
            type: :boolean,
            description: "whether the user allows automatically follow moved following accounts"
          },
          background_image: %Schema{type: :string, nullable: true, format: :uri},
          chat_token: %Schema{type: :string},
          is_confirmed: %Schema{
            type: :boolean,
            description:
              "whether the user account is waiting on email confirmation to be activated"
          },
          hide_favorites: %Schema{type: :boolean},
          hide_followers_count: %Schema{
            type: :boolean,
            description: "whether the user has follower stat hiding enabled"
          },
          hide_followers: %Schema{
            type: :boolean,
            description: "whether the user has follower hiding enabled"
          },
          hide_follows_count: %Schema{
            type: :boolean,
            description: "whether the user has follow stat hiding enabled"
          },
          hide_follows: %Schema{
            type: :boolean,
            description: "whether the user has follow hiding enabled"
          },
          is_admin: %Schema{
            type: :boolean,
            description: "whether the user is an admin of the local instance"
          },
          is_moderator: %Schema{
            type: :boolean,
            description: "whether the user is a moderator of the local instance"
          },
          skip_thread_containment: %Schema{type: :boolean},
          tags: %Schema{
            type: :array,
            items: %Schema{type: :string},
            description:
              "List of tags being used for things like extra roles or moderation(ie. marking all media as nsfw all)."
          },
          unread_conversation_count: %Schema{
            type: :integer,
            description: "The count of unread conversations. Only returned to the account owner."
          },
          notification_settings: %Schema{
            type: :object,
            properties: %{
              block_from_strangers: %Schema{type: :boolean},
              hide_notification_contents: %Schema{type: :boolean}
            }
          },
          relationship: %Schema{allOf: [AccountRelationship], nullable: true},
          settings_store: %Schema{
            type: :object,
            description:
              "A generic map of settings for frontends. Opaque to the backend. Only returned in `verify_credentials` and `update_credentials`"
          },
          accepts_chat_messages: %Schema{type: :boolean, nullable: true},
          favicon: %Schema{
            type: :string,
            format: :uri,
            nullable: true,
            description: "Favicon image of the user's instance"
          }
        }
      },
      source: %Schema{
        type: :object,
        properties: %{
          fields: %Schema{type: :array, items: AccountField},
          note: %Schema{
            type: :string,
            description:
              "Plaintext version of the bio without formatting applied by the backend, used for editing the bio."
          },
          privacy: VisibilityScope,
          sensitive: %Schema{type: :boolean},
          pleroma: %Schema{
            type: :object,
            properties: %{
              actor_type: ActorType,
              discoverable: %Schema{
                type: :boolean,
                description:
                  "whether the user allows indexing / listing of the account by external services (search engines etc.)."
              },
              no_rich_text: %Schema{
                type: :boolean,
                description:
                  "whether the HTML tags for rich-text formatting are stripped from all statuses requested from the API."
              },
              show_role: %Schema{
                type: :boolean,
                description:
                  "whether the user wants their role (e.g admin, moderator) to be shown"
              }
            }
          }
        }
      }
    },
    example: %{
      "acct" => "foobar",
      "avatar" => "https://mypleroma.com/images/avi.png",
      "avatar_static" => "https://mypleroma.com/images/avi.png",
      "bot" => false,
      "created_at" => "2020-03-24T13:05:58.000Z",
      "display_name" => "foobar",
      "emojis" => [],
      "fields" => [],
      "follow_requests_count" => 0,
      "followers_count" => 0,
      "following_count" => 1,
      "header" => "https://mypleroma.com/images/banner.png",
      "header_static" => "https://mypleroma.com/images/banner.png",
      "id" => "9tKi3esbG7OQgZ2920",
      "locked" => false,
      "note" => "cofe",
      "pleroma" => %{
        "allow_following_move" => true,
        "background_image" => nil,
        "is_confirmed" => false,
        "hide_favorites" => true,
        "hide_followers" => false,
        "hide_followers_count" => false,
        "hide_follows" => false,
        "hide_follows_count" => false,
        "is_admin" => false,
        "is_moderator" => false,
        "skip_thread_containment" => false,
        "accepts_chat_messages" => true,
        "chat_token" =>
          "SFMyNTY.g3QAAAACZAAEZGF0YW0AAAASOXRLaTNlc2JHN09RZ1oyOTIwZAAGc2lnbmVkbgYARNplS3EB.Mb_Iaqew2bN1I1o79B_iP7encmVCpTKC4OtHZRxdjKc",
        "unread_conversation_count" => 0,
        "tags" => [],
        "notification_settings" => %{
          "block_from_strangers" => false,
          "hide_notification_contents" => false
        },
        "relationship" => %{
          "blocked_by" => false,
          "blocking" => false,
          "domain_blocking" => false,
          "endorsed" => false,
          "followed_by" => false,
          "following" => false,
          "id" => "9tKi3esbG7OQgZ2920",
          "muting" => false,
          "muting_notifications" => false,
          "note" => "",
          "requested" => false,
          "showing_reblogs" => true,
          "subscribing" => false,
          "notifying" => false
        },
        "settings_store" => %{
          "pleroma-fe" => %{}
        }
      },
      "source" => %{
        "fields" => [],
        "note" => "foobar",
        "pleroma" => %{
          "actor_type" => "Person",
          "discoverable" => false,
          "no_rich_text" => false,
          "show_role" => true
        },
        "privacy" => "public",
        "sensitive" => false
      },
      "statuses_count" => 0,
      "url" => "https://mypleroma.com/users/foobar",
      "username" => "foobar"
    }
  })
end
