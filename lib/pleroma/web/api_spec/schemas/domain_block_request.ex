# Pleroma: A lightweight social networking server
# Copyright © 2017-2020 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.ApiSpec.Schemas.DomainBlockRequest do
  alias OpenApiSpex.Schema
  require OpenApiSpex

  OpenApiSpex.schema(%{
    title: "DomainBlockRequest",
    type: :object,
    properties: %{
      domain: %Schema{type: :string}
    },
    required: [:domain],
    example: %{
      "domain" => "facebook.com"
    }
  })
end
