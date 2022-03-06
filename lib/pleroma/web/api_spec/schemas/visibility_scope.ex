# Pleroma: A lightweight social networking server
# Copyright © 2017-2022 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.ApiSpec.Schemas.VisibilityScope do
  require OpenApiSpex

  OpenApiSpex.schema(%{
    title: "VisibilityScope",
    description: "Status visibility",
    type: :string,
    enum: ["public", "unlisted", "local", "private", "direct", "list"]
  })
end
