# Pleroma: A lightweight social networking server
# Copyright © 2017-2021 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.ApiSpec.Schemas.Conversation do
  alias OpenApiSpex.Schema
  alias Pleroma.Web.ApiSpec.Schemas.Account
  alias Pleroma.Web.ApiSpec.Schemas.Status

  require OpenApiSpex

  OpenApiSpex.schema(%{
    title: "Conversation",
    description: "Represents a conversation with \"direct message\" visibility.",
    type: :object,
    required: [:id, :accounts, :unread],
    properties: %{
      id: %Schema{type: :string},
      accounts: %Schema{
        type: :array,
        items: Account,
        description: "Participants in the conversation"
      },
      unread: %Schema{
        type: :boolean,
        description: "Is the conversation currently marked as unread?"
      },
      # last_status: Status
      last_status: %Schema{
        allOf: [Status],
        description: "The last status in the conversation, to be used for optional display"
      }
    },
    example: %{
      "id" => "418450",
      "unread" => true,
      "accounts" => [Account.schema().example],
      "last_status" => Status.schema().example
    }
  })
end
