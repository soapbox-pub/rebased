# Pleroma: A lightweight social networking server
# Copyright © 2017-2020 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.ApiSpec.Schemas.AccountFollowsRequest do
  alias OpenApiSpex.Schema
  require OpenApiSpex

  OpenApiSpex.schema(%{
    title: "AccountFollowsRequest",
    description: "POST body for muting an account",
    type: :object,
    properties: %{
      uri: %Schema{type: :string, format: :uri}
    },
    required: [:uri]
  })
end
