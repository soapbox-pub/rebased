# Pleroma: A lightweight social networking server
# Copyright © 2017-2021 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.ApiSpec.Schemas.Group do
  alias OpenApiSpex.Schema
  alias Pleroma.Web.ApiSpec.Schemas.AccountField
  alias Pleroma.Web.ApiSpec.Schemas.Emoji
  alias Pleroma.Web.ApiSpec.Schemas.FlakeID
  alias Pleroma.Web.ApiSpec.Schemas.PrivacyScope

  require OpenApiSpex

  OpenApiSpex.schema(%{
    title: "Group",
    description: "Response schema for a group",
    type: :object,
    properties: %{
      acct: %Schema{type: :string},
      avatar_static: %Schema{type: :string, format: :uri},
      avatar: %Schema{type: :string, format: :uri},
      created_at: %Schema{type: :string, format: "date-time"},
      display_name: %Schema{type: :string},
      emojis: %Schema{type: :array, items: Emoji},
      fields: %Schema{type: :array, items: AccountField},
      members_count: %Schema{type: :integer},
      header_static: %Schema{type: :string, format: :uri},
      header: %Schema{type: :string, format: :uri},
      id: FlakeID,
      locked: %Schema{type: :boolean},
      note: %Schema{type: :string, format: :html},
      slug: %Schema{type: :string},
      statuses_count: %Schema{type: :integer},
      url: %Schema{type: :string, format: :uri},
      source: %Schema{
        type: :object,
        properties: %{
          fields: %Schema{type: :array, items: AccountField},
          note: %Schema{
            type: :string,
            description:
              "Plaintext version of the description without formatting applied by the backend, used for editing the description."
          },
          privacy: PrivacyScope
        }
      }
    },
    example: %{
      "acct" => "dogelovers",
      "avatar" => "https://mypleroma.com/images/avi.png",
      "avatar_static" => "https://mypleroma.com/images/avi.png",
      "created_at" => "2021-06-26T13:04:20.000Z",
      "display_name" => "Doge Lovers of Fedi",
      "emojis" => [],
      "fields" => [],
      "members_count" => 420,
      "header" => "https://mypleroma.com/images/banner.png",
      "header_static" => "https://mypleroma.com/images/banner.png",
      "id" => "A8fI1zwFiqcRYXgBIu",
      "locked" => false,
      "note" => "The Fediverse's largest meme group. Join to laugh and have fun.",
      "source" => %{
        "fields" => [],
        "note" => "The Fediverse's largest meme group. Join to laugh and have fun.",
        "privacy" => "public"
      },
      "statuses_count" => 9001,
      "url" => "https://mypleroma.com/groups/dogelovers",
      "slug" => "dogelovers"
    }
  })
end
