# Pleroma: A lightweight social networking server
# Copyright © 2017-2020 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.ApiSpec.Schemas.ListsResponse do
  alias Pleroma.Web.ApiSpec.Schemas.List

  require OpenApiSpex

  OpenApiSpex.schema(%{
    title: "ListsResponse",
    description: "Response schema for lists",
    type: :array,
    items: List
  })
end
