# Pleroma: A lightweight social networking server
# Copyright © 2017-2021 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.ApiSpec.Schemas.GroupRelationship do
  alias OpenApiSpex.Schema
  alias Pleroma.Web.ApiSpec.Schemas.FlakeID

  require OpenApiSpex

  OpenApiSpex.schema(%{
    title: "GroupRelationship",
    description: "Relationship between current account and requested group",
    type: :object,
    properties: %{
      id: FlakeID,
      requested: %Schema{type: :boolean},
      member: %Schema{type: :boolean},
      owner: %Schema{type: :boolean},
      admin: %Schema{type: :boolean},
      moderator: %Schema{type: :boolean}
    },
    example: %{
      "id" => "A8fI1zwFiqcRYXgBIu",
      "requested" => true,
      "member" => false,
      "owner" => false,
      "admin" => false,
      "moderator" => false
    }
  })
end
