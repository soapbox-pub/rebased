# Pleroma: A lightweight social networking server
# Copyright © 2017-2021 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.ApiSpec.Schemas.ActorType do
  require OpenApiSpex

  OpenApiSpex.schema(%{
    title: "ActorType",
    type: :string,
    enum: ["Application", "Group", "Organization", "Person", "Service"]
  })
end
