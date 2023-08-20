# Pleroma: A lightweight social networking server
# Copyright © 2017-2022 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.ApiSpec.Schemas.ParticipationRequest do
  alias OpenApiSpex.Schema
  alias Pleroma.Web.ApiSpec.Schemas.Account

  require OpenApiSpex

  OpenApiSpex.schema(%{
    title: "ParticipationRequest",
    description: "Represents an event participation request",
    type: :object,
    properties: %{
      account: %Schema{
        allOf: [Account],
        description: "The account that wants to participate in the event."
      },
      participation_message: %Schema{
        type: :string,
        description: "Why the user wants to participate"
      }
    },
    example: %{
      "account" => Account.schema().example,
      "participation_message" => "I'm interested in this event"
    }
  })
end
