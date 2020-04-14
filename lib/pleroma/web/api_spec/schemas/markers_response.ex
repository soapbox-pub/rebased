# Pleroma: A lightweight social networking server
# Copyright © 2017-2020 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.ApiSpec.Schemas.MarkersResponse do
  require OpenApiSpex
  alias OpenApiSpex.Schema

  alias Pleroma.Web.ApiSpec.Schemas.Marker

  OpenApiSpex.schema(%{
    title: "MarkersResponse",
    description: "Response schema for markers",
    type: :object,
    properties: %{
      notifications: %Schema{allOf: [Marker], nullable: true},
      home: %Schema{allOf: [Marker], nullable: true}
    },
    items: %Schema{type: :string},
    example: %{
      "notifications" => %{
        "last_read_id" => "35098814",
        "version" => 361,
        "updated_at" => "2019-11-26T22:37:25.239Z",
        "pleroma" => %{"unread_count" => 0}
      },
      "home" => %{
        "last_read_id" => "103206604258487607",
        "version" => 468,
        "updated_at" => "2019-11-26T22:37:25.235Z",
        "pleroma" => %{"unread_count" => 10}
      }
    }
  })
end
