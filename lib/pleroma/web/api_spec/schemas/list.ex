# Pleroma: A lightweight social networking server
# Copyright © 2017-2020 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.ApiSpec.Schemas.List do
  alias OpenApiSpex.Schema

  require OpenApiSpex

  OpenApiSpex.schema(%{
    title: "List",
    description: "Response schema for a list",
    type: :object,
    properties: %{
      id: %Schema{type: :string},
      title: %Schema{type: :string}
    },
    example: %{
      "JSON" => %{
        "id" => "123",
        "title" => "my list"
      }
    }
  })
end
