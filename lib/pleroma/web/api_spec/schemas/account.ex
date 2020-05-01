# Pleroma: A lightweight social networking server
# Copyright © 2017-2020 Pleroma Authors <https://pleroma.social/>
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
          allow_following_move: %Schema{type: :boolean},
          background_image: %Schema{type: :string, nullable: true},
          chat_token: %Schema{type: :string},
          confirmation_pending: %Schema{type: :boolean},
          hide_favorites: %Schema{type: :boolean},
          hide_followers_count: %Schema{type: :boolean},
          hide_followers: %Schema{type: :boolean},
          hide_follows_count: %Schema{type: :boolean},
          hide_follows: %Schema{type: :boolean},
          is_admin: %Schema{type: :boolean},
          is_moderator: %Schema{type: :boolean},
          skip_thread_containment: %Schema{type: :boolean},
          tags: %Schema{type: :array, items: %Schema{type: :string}},
          unread_conversation_count: %Schema{type: :integer},
          notification_settings: %Schema{
            type: :object,
            properties: %{
              followers: %Schema{type: :boolean},
              follows: %Schema{type: :boolean},
              non_followers: %Schema{type: :boolean},
              non_follows: %Schema{type: :boolean},
              privacy_option: %Schema{type: :boolean}
            }
          },
          relationship: AccountRelationship,
          settings_store: %Schema{
            type: :object
          }
        }
      },
      source: %Schema{
        type: :object,
        properties: %{
          fields: %Schema{type: :array, items: AccountField},
          note: %Schema{type: :string},
          privacy: VisibilityScope,
          sensitive: %Schema{type: :boolean},
          pleroma: %Schema{
            type: :object,
            properties: %{
              actor_type: ActorType,
              discoverable: %Schema{type: :boolean},
              no_rich_text: %Schema{type: :boolean},
              show_role: %Schema{type: :boolean}
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
        "confirmation_pending" => true,
        "hide_favorites" => true,
        "hide_followers" => false,
        "hide_followers_count" => false,
        "hide_follows" => false,
        "hide_follows_count" => false,
        "is_admin" => false,
        "is_moderator" => false,
        "skip_thread_containment" => false,
        "chat_token" =>
          "SFMyNTY.g3QAAAACZAAEZGF0YW0AAAASOXRLaTNlc2JHN09RZ1oyOTIwZAAGc2lnbmVkbgYARNplS3EB.Mb_Iaqew2bN1I1o79B_iP7encmVCpTKC4OtHZRxdjKc",
        "unread_conversation_count" => 0,
        "tags" => [],
        "notification_settings" => %{
          "followers" => true,
          "follows" => true,
          "non_followers" => true,
          "non_follows" => true,
          "privacy_option" => false
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
          "requested" => false,
          "showing_reblogs" => true,
          "subscribing" => false
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
