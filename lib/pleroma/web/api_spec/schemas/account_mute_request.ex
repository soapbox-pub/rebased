# Pleroma: A lightweight social networking server
# Copyright © 2017-2020 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.ApiSpec.Schemas.AccountMuteRequest do
  alias OpenApiSpex.Schema
  require OpenApiSpex

  OpenApiSpex.schema(%{
    title: "AccountMuteRequest",
    description: "POST body for muting an account",
    type: :object,
    properties: %{
      notifications: %Schema{
        type: :boolean,
        description: "Mute notifications in addition to statuses? Defaults to true.",
        default: true
      }
    },
    example: %{
      "notifications" => true
    }
  })
end
