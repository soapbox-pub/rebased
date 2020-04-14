# Pleroma: A lightweight social networking server
# Copyright © 2017-2020 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.ApiSpec.Schemas.MarkersUpsertRequest do
  require OpenApiSpex
  alias OpenApiSpex.Schema

  OpenApiSpex.schema(%{
    title: "MarkersUpsertRequest",
    description: "Request schema for marker upsert",
    type: :object,
    properties: %{
      notifications: %Schema{
        type: :object,
        properties: %{
          last_read_id: %Schema{type: :string}
        }
      },
      home: %Schema{
        type: :object,
        properties: %{
          last_read_id: %Schema{type: :string}
        }
      }
    },
    example: %{
      "home" => %{
        "last_read_id" => "103194548672408537",
        "version" => 462,
        "updated_at" => "2019-11-24T19:39:39.337Z"
      }
    }
  })
end
