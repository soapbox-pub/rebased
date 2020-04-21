# Pleroma: A lightweight social networking server
# Copyright © 2017-2020 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.ApiSpec.Schemas.AccountCreateResponse do
  alias OpenApiSpex.Schema

  require OpenApiSpex

  OpenApiSpex.schema(%{
    title: "AccountCreateResponse",
    description: "Response schema for an account",
    type: :object,
    properties: %{
      token_type: %Schema{type: :string},
      access_token: %Schema{type: :string},
      scope: %Schema{type: :array, items: %Schema{type: :string}},
      created_at: %Schema{type: :integer, format: :"date-time"}
    },
    example: %{
      "access_token" => "i9hAVVzGld86Pl5JtLtizKoXVvtTlSCJvwaugCxvZzk",
      "created_at" => 1_585_918_714,
      "scope" => ["read", "write", "follow", "push"],
      "token_type" => "Bearer"
    }
  })
end
