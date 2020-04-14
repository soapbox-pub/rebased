# Pleroma: A lightweight social networking server
# Copyright © 2017-2020 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.ApiSpec.Schemas.FilterCreateRequest do
  alias OpenApiSpex.Schema
  require OpenApiSpex

  OpenApiSpex.schema(%{
    title: "FilterCreateRequest",
    allOf: [
      %OpenApiSpex.Reference{"$ref": "#/components/schemas/FilterUpdateRequest"},
      %Schema{
        type: :object,
        properties: %{
          irreversible: %Schema{
            type: :bolean,
            description:
              "Should the server irreversibly drop matching entities from home and notifications?",
            default: false
          }
        }
      }
    ],
    example: %{
      "phrase" => "knights",
      "context" => ["home"]
    }
  })
end
