# Pleroma: A lightweight social networking server
# Copyright © 2017-2022 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.ApiSpec.Schemas.BooleanLike do
  alias OpenApiSpex.Cast
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
    ],
    "x-validate": __MODULE__
  })

  def cast(%Cast{value: value} = context) do
    context
    |> Map.put(:value, Pleroma.Web.Utils.Params.truthy_param?(value))
    |> Cast.ok()
  end
end
