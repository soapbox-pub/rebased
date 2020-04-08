# Pleroma: A lightweight social networking server
# Copyright © 2017-2020 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.ApiSpec.Schemas.AccountsResponse do
  require OpenApiSpex

  OpenApiSpex.schema(%{
    title: "AccountsResponse",
    type: :array,
    items: Pleroma.Web.ApiSpec.Schemas.Account
  })
end
