# Pleroma: A lightweight social networking server
# Copyright © 2017-2020 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.ApiSpec.Schemas.StatusesResponse do
  require OpenApiSpex

  OpenApiSpex.schema(%{
    title: "StatusesResponse",
    type: :array,
    items: Pleroma.Web.ApiSpec.Schemas.Status
  })
end
