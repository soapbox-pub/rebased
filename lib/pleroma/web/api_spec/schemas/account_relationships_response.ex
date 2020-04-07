# Pleroma: A lightweight social networking server
# Copyright © 2017-2020 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.ApiSpec.Schemas.AccountRelationshipsResponse do
  require OpenApiSpex

  OpenApiSpex.schema(%{
    title: "AccountRelationshipsResponse",
    description: "Response schema for account relationships",
    type: :array,
    items: Pleroma.Web.ApiSpec.Schemas.AccountRelationshipResponse,
    example: [
      %{
        "id" => "1",
        "following" => true,
        "showing_reblogs" => true,
        "followed_by" => true,
        "blocking" => false,
        "blocked_by" => true,
        "muting" => false,
        "muting_notifications" => false,
        "requested" => false,
        "domain_blocking" => false,
        "endorsed" => true
      },
      %{
        "id" => "2",
        "following" => true,
        "showing_reblogs" => true,
        "followed_by" => true,
        "blocking" => false,
        "blocked_by" => true,
        "muting" => true,
        "muting_notifications" => false,
        "requested" => true,
        "domain_blocking" => false,
        "endorsed" => false
      },
      %{
        "id" => "3",
        "following" => true,
        "showing_reblogs" => true,
        "followed_by" => true,
        "blocking" => true,
        "blocked_by" => false,
        "muting" => true,
        "muting_notifications" => false,
        "requested" => false,
        "domain_blocking" => true,
        "endorsed" => false
      }
    ]
  })
end
