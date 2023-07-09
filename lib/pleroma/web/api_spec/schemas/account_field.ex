# Pleroma: A lightweight social networking server
# Copyright © 2017-2022 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.ApiSpec.Schemas.AccountField do
  alias OpenApiSpex.Schema

  require OpenApiSpex

  OpenApiSpex.schema(%{
    title: "AccountField",
    description: "Response schema for account custom fields",
    type: :object,
    properties: %{
      name: %Schema{type: :string},
      value: %Schema{type: :string, format: :html},
      verified_at: %Schema{type: :string, format: :"date-time", nullable: true}
    },
    example: %{
      "name" => "Website",
      "value" =>
        "<a href=\"https://pleroma.com\" rel=\"me nofollow noopener noreferrer\" target=\"_blank\"><span class=\"invisible\">https://</span><span class=\"\">pleroma.com</span><span class=\"invisible\"></span></a>",
      "verified_at" => "2019-08-29T04:14:55.571+00:00"
    }
  })
end
