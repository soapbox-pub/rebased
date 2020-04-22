# Pleroma: A lightweight social networking server
# Copyright © 2017-2020 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.ApiSpec.CustomEmojiOperation do
  alias OpenApiSpex.Operation
  alias Pleroma.Web.ApiSpec.Schemas.CustomEmojisResponse

  def open_api_operation(action) do
    operation = String.to_existing_atom("#{action}_operation")
    apply(__MODULE__, operation, [])
  end

  def index_operation do
    %Operation{
      tags: ["custom_emojis"],
      summary: "List custom custom emojis",
      description: "Returns custom emojis that are available on the server.",
      operationId: "CustomEmojiController.index",
      responses: %{
        200 => Operation.response("Custom Emojis", "application/json", CustomEmojisResponse)
      }
    }
  end
end
