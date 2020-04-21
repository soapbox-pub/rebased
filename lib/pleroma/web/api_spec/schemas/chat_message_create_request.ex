# Pleroma: A lightweight social networking server
# Copyright © 2017-2020 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.ApiSpec.Schemas.ChatMessageCreateRequest do
  alias OpenApiSpex.Schema
  require OpenApiSpex

  OpenApiSpex.schema(%{
    title: "ChatMessageCreateRequest",
    description: "POST body for creating an chat message",
    type: :object,
    properties: %{
      content: %Schema{type: :string, description: "The content of your message"}
    },
    example: %{
      "content" => "Hey wanna buy feet pics?"
    }
  })
end
