# Pleroma: A lightweight social networking server
# Copyright © 2017-2022 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.ApiSpec.PleromaStatusOperation do
  alias OpenApiSpex.Operation
  alias Pleroma.Web.ApiSpec.Schemas.ApiError
  alias Pleroma.Web.ApiSpec.Schemas.FlakeID
  alias Pleroma.Web.ApiSpec.Schemas.Status

  def open_api_operation(action) do
    operation = String.to_existing_atom("#{action}_operation")
    apply(__MODULE__, operation, [])
  end

  def subscribe_conversation_operation do
    %Operation{
      tags: ["Status actions"],
      summary: "Subscribe conversation",
      security: [%{"oAuth" => ["write:notifications"]}],
      description:
        "Receive notifications for new replies in the thread that this status is part of",
      operationId: "StatusController.subscribe_conversation",
      parameters: [
        id_param()
      ],
      responses: %{
        200 => status_response(),
        400 => Operation.response("Error", "application/json", ApiError)
      }
    }
  end

  def unsubscribe_conversation_operation do
    %Operation{
      tags: ["Status actions"],
      summary: "Unsubscribe conversation",
      security: [%{"oAuth" => ["write:notifications"]}],
      description:
        "Stop receiving notifications for new replies in the thread that this status is part of",
      operationId: "StatusController.unsubscribe_conversation",
      parameters: [id_param()],
      responses: %{
        200 => status_response(),
        400 => Operation.response("Error", "application/json", ApiError)
      }
    }
  end

  def id_param do
    Operation.parameter(:id, :path, FlakeID, "Status ID",
      example: "9umDrYheeY451cQnEe",
      required: true
    )
  end

  defp status_response do
    Operation.response("Status", "application/json", Status)
  end
end
