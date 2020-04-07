# Pleroma: A lightweight social networking server
# Copyright © 2017-2020 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.ApiSpec.Schemas.AccountRelationshipResponse do
  alias OpenApiSpex.Schema

  require OpenApiSpex

  OpenApiSpex.schema(%{
    title: "AccountRelationshipResponse",
    description: "Response schema for an account relationship",
    type: :object,
    properties: %{
      id: %Schema{type: :string},
      following: %Schema{type: :boolean},
      showing_reblogs: %Schema{type: :boolean},
      followed_by: %Schema{type: :boolean},
      blocking: %Schema{type: :boolean},
      blocked_by: %Schema{type: :boolean},
      muting: %Schema{type: :boolean},
      muting_notifications: %Schema{type: :boolean},
      requested: %Schema{type: :boolean},
      domain_blocking: %Schema{type: :boolean},
      endorsed: %Schema{type: :boolean}
    },
    example: %{
      "JSON" => %{
        "id" => "1",
        "following" => true,
        "showing_reblogs" => true,
        "followed_by" => true,
        "blocking" => false,
        "blocked_by" => false,
        "muting" => false,
        "muting_notifications" => false,
        "requested" => false,
        "domain_blocking" => false,
        "endorsed" => false
      }
    }
  })
end
