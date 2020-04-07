# Pleroma: A lightweight social networking server
# Copyright © 2017-2020 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.ApiSpec.Schemas.AccountUpdateCredentialsRequest do
  alias OpenApiSpex.Schema
  alias Pleroma.Web.ApiSpec.Schemas.AccountAttributeField
  alias Pleroma.Web.ApiSpec.Schemas.ActorType
  alias Pleroma.Web.ApiSpec.Schemas.VisibilityScope
  require OpenApiSpex

  OpenApiSpex.schema(%{
    title: "AccountUpdateCredentialsRequest",
    description: "POST body for creating an account",
    type: :object,
    properties: %{
      bot: %Schema{
        type: :boolean,
        description: "Whether the account has a bot flag."
      },
      display_name: %Schema{
        type: :string,
        description: "The display name to use for the profile."
      },
      note: %Schema{type: :string, description: "The account bio."},
      avatar: %Schema{
        type: :string,
        description: "Avatar image encoded using multipart/form-data",
        format: :binary
      },
      header: %Schema{
        type: :string,
        description: "Header image encoded using multipart/form-data",
        format: :binary
      },
      locked: %Schema{
        type: :boolean,
        description: "Whether manual approval of follow requests is required."
      },
      fields_attributes: %Schema{
        oneOf: [%Schema{type: :array, items: AccountAttributeField}, %Schema{type: :object}]
      },
      # NOTE: `source` field is not supported
      #
      # source: %Schema{
      #   type: :object,
      #   properties: %{
      #     privacy: %Schema{type: :string},
      #     sensitive: %Schema{type: :boolean},
      #     language: %Schema{type: :string}
      #   }
      # },

      # Pleroma-specific fields
      no_rich_text: %Schema{
        type: :boolean,
        description: "html tags are stripped from all statuses requested from the API"
      },
      hide_followers: %Schema{type: :boolean, description: "user's followers will be hidden"},
      hide_follows: %Schema{type: :boolean, description: "user's follows will be hidden"},
      hide_followers_count: %Schema{
        type: :boolean,
        description: "user's follower count will be hidden"
      },
      hide_follows_count: %Schema{
        type: :boolean,
        description: "user's follow count will be hidden"
      },
      hide_favorites: %Schema{
        type: :boolean,
        description: "user's favorites timeline will be hidden"
      },
      show_role: %Schema{
        type: :boolean,
        description: "user's role (e.g admin, moderator) will be exposed to anyone in the
      API"
      },
      default_scope: VisibilityScope,
      pleroma_settings_store: %Schema{
        type: :object,
        description: "Opaque user settings to be saved on the backend."
      },
      skip_thread_containment: %Schema{
        type: :boolean,
        description: "Skip filtering out broken threads"
      },
      allow_following_move: %Schema{
        type: :boolean,
        description: "Allows automatically follow moved following accounts"
      },
      pleroma_background_image: %Schema{
        type: :string,
        description: "Sets the background image of the user.",
        format: :binary
      },
      discoverable: %Schema{
        type: :boolean,
        description: "Discovery of this account in search results and other services is allowed."
      },
      actor_type: ActorType
    },
    example: %{
      bot: false,
      display_name: "cofe",
      note: "foobar",
      fields_attributes: [%{name: "foo", value: "bar"}],
      no_rich_text: false,
      hide_followers: true,
      hide_follows: false,
      hide_followers_count: false,
      hide_follows_count: false,
      hide_favorites: false,
      show_role: false,
      default_scope: "private",
      pleroma_settings_store: %{"pleroma-fe" => %{"key" => "val"}},
      skip_thread_containment: false,
      allow_following_move: false,
      discoverable: false,
      actor_type: "Person"
    }
  })
end
