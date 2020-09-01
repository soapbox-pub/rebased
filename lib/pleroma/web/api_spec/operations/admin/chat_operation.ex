# Pleroma: A lightweight social networking server
# Copyright © 2017-2020 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.ApiSpec.Admin.ChatOperation do
  alias OpenApiSpex.Operation
  alias Pleroma.Web.ApiSpec.Schemas.ApiError
  alias Pleroma.Web.ApiSpec.Schemas.FlakeID

  import Pleroma.Web.ApiSpec.Helpers

  def open_api_operation(action) do
    operation = String.to_existing_atom("#{action}_operation")
    apply(__MODULE__, operation, [])
  end

  def delete_message_operation do
    %Operation{
      tags: ["Admin", "Chats"],
      summary: "Delete an individual chat message",
      operationId: "AdminAPI.ChatController.delete",
      parameters: [id_param(), message_id_param()] ++ admin_api_params(),
      security: [%{"oAuth" => ["write:chats"]}],
      responses: %{
        200 => empty_object_response(),
        404 => Operation.response("Not Found", "application/json", ApiError)
      }
    }
  end

  def id_param do
    Operation.parameter(:id, :path, FlakeID, "Chat ID",
      example: "9umDrYheeY451cQnEe",
      required: true
    )
  end

  def message_id_param do
    Operation.parameter(:message_id, :path, FlakeID, "Chat message ID",
      example: "9umDrYheeY451cQnEe",
      required: true
    )
  end
end
