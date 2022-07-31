# Pleroma: A lightweight social networking server
# Copyright © 2017-2022 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.ApiSpec.Schemas.AccountRelationship do
  alias OpenApiSpex.Schema
  alias Pleroma.Web.ApiSpec.Schemas.FlakeID

  require OpenApiSpex

  OpenApiSpex.schema(%{
    title: "AccountRelationship",
    description: "Relationship between current account and requested account",
    type: :object,
    properties: %{
      blocked_by: %Schema{type: :boolean},
      blocking: %Schema{type: :boolean},
      domain_blocking: %Schema{type: :boolean},
      endorsed: %Schema{type: :boolean},
      followed_by: %Schema{type: :boolean},
      following: %Schema{type: :boolean},
      id: FlakeID,
      muting: %Schema{type: :boolean},
      muting_notifications: %Schema{type: :boolean},
      note: %Schema{type: :string},
      requested: %Schema{type: :boolean},
      showing_reblogs: %Schema{type: :boolean},
      subscribing: %Schema{type: :boolean},
      notifying: %Schema{type: :boolean}
    },
    example: %{
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
    }
  })
end
