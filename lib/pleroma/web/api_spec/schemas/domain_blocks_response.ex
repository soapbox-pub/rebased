# Pleroma: A lightweight social networking server
# Copyright © 2017-2020 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.ApiSpec.Schemas.DomainBlocksResponse do
  require OpenApiSpex
  alias OpenApiSpex.Schema

  OpenApiSpex.schema(%{
    title: "DomainBlocksResponse",
    description: "Response schema for domain blocks",
    type: :array,
    items: %Schema{type: :string},
    example: ["google.com", "facebook.com"]
  })
end
