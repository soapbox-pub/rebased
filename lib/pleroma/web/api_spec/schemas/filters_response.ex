# Pleroma: A lightweight social networking server
# Copyright © 2017-2020 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.ApiSpec.Schemas.FiltersResponse do
  require OpenApiSpex
  alias Pleroma.Web.ApiSpec.Schemas.Filter

  OpenApiSpex.schema(%{
    title: "FiltersResponse",
    description: "Array of Filters",
    type: :array,
    items: Filter,
    example: [
      %{
        "id" => "5580",
        "phrase" => "@twitter.com",
        "context" => [
          "home",
          "notifications",
          "public",
          "thread"
        ],
        "whole_word" => false,
        "expires_at" => nil,
        "irreversible" => true
      },
      %{
        "id" => "6191",
        "phrase" => ":eurovision2019:",
        "context" => [
          "home"
        ],
        "whole_word" => true,
        "expires_at" => "2019-05-21T13:47:31.333Z",
        "irreversible" => false
      }
    ]
  })
end
