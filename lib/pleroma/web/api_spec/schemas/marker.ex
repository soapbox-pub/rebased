# Pleroma: A lightweight social networking server
# Copyright © 2017-2020 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.ApiSpec.Schemas.Marker do
  require OpenApiSpex
  alias OpenApiSpex.Schema

  OpenApiSpex.schema(%{
    title: "Marker",
    description: "Schema for a marker",
    type: :object,
    properties: %{
      last_read_id: %Schema{type: :string},
      version: %Schema{type: :integer},
      updated_at: %Schema{type: :string},
      pleroma: %Schema{
        type: :object,
        properties: %{
          unread_count: %Schema{type: :integer}
        }
      }
    },
    example: %{
      "last_read_id" => "35098814",
      "version" => 361,
      "updated_at" => "2019-11-26T22:37:25.239Z",
      "pleroma" => %{"unread_count" => 5}
    }
  })
end
