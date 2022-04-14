# Pleroma: A lightweight social networking server
# Copyright © 2017-2022 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.ApiSpec.Schemas.ApiError do
  alias OpenApiSpex.Schema

  require OpenApiSpex

  OpenApiSpex.schema(%{
    title: "ApiError",
    description: "Response schema for API error",
    type: :object,
    properties: %{error: %Schema{type: :string}},
    example: %{
      "error" => "Something went wrong"
    }
  })
end
