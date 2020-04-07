# Pleroma: A lightweight social networking server
# Copyright © 2017-2020 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.ApiSpec.Schemas.AccountAttributeField do
  alias OpenApiSpex.Schema

  require OpenApiSpex

  OpenApiSpex.schema(%{
    title: "AccountAttributeField",
    description: "Request schema for account custom fields",
    type: :object,
    properties: %{
      name: %Schema{type: :string},
      value: %Schema{type: :string}
    },
    required: [:name, :value],
    example: %{
      "JSON" => %{
        "name" => "Website",
        "value" => "https://pleroma.com"
      }
    }
  })
end
