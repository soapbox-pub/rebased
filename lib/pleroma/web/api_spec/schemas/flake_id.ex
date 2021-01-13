# Pleroma: A lightweight social networking server
# Copyright © 2017-2021 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.ApiSpec.Schemas.FlakeID do
  require OpenApiSpex

  OpenApiSpex.schema(%{
    title: "FlakeID",
    description:
      "Pleroma uses 128-bit ids as opposed to Mastodon's 64 bits. However just like Mastodon's ids they are lexically sortable strings",
    type: :string
  })
end
