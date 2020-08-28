# Pleroma: A lightweight social networking server
# Copyright © 2017-2020 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.ApiSpec.Schemas.BooleanLike do
  alias OpenApiSpex.Schema

  require OpenApiSpex

  OpenApiSpex.schema(%{
    title: "BooleanLike",
    description: """
    The following values will be treated as `false`:
      - false
      - 0
      - "0",
      - "f",
      - "F",
      - "false",
      - "FALSE",
      - "off",
      - "OFF"

    All other non-null values will be treated as `true`
    """,
    anyOf: [
      %Schema{type: :boolean},
      %Schema{type: :string},
      %Schema{type: :integer}
    ]
  })

  def after_cast(value, _schmea) do
    {:ok, Pleroma.Web.ControllerHelper.truthy_param?(value)}
  end
end
