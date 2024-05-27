# Pleroma: A lightweight social networking server
# Copyright © 2017-2024 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.ApiSpec.Schemas.BookmarkFolder do
  alias OpenApiSpex.Schema
  alias Pleroma.Web.ApiSpec.Schemas.FlakeID

  require OpenApiSpex

  OpenApiSpex.schema(%{
    title: "BookmarkFolder",
    description: "Response schema for a bookmark folder",
    type: :object,
    properties: %{
      id: FlakeID,
      name: %Schema{type: :string, description: "Folder name"},
      emoji: %Schema{type: :string, description: "Folder emoji", nullable: true}
    },
    example: %{
      "id" => "9toJCu5YZW7O7gfvH6",
      "name" => "Read later",
      "emoji" => nil
    }
  })
end
