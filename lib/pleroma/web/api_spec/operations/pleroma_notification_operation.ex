# Pleroma: A lightweight social networking server
# Copyright © 2017-2022 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.ApiSpec.PleromaNotificationOperation do
  alias OpenApiSpex.Operation
  alias OpenApiSpex.Schema
  alias Pleroma.Web.ApiSpec.NotificationOperation
  alias Pleroma.Web.ApiSpec.Schemas.ApiError

  import Pleroma.Web.ApiSpec.Helpers

  def open_api_operation(action) do
    operation = String.to_existing_atom("#{action}_operation")
    apply(__MODULE__, operation, [])
  end

  def mark_as_read_operation do
    %Operation{
      tags: ["Notifications"],
      summary: "Mark notifications as read",
      description: "Query parameters are mutually exclusive.",
      requestBody:
        request_body("Parameters", %Schema{
          type: :object,
          properties: %{
            id: %Schema{type: :integer, description: "A single notification ID to read"},
            max_id: %Schema{type: :integer, description: "Read all notifications up to this ID"}
          }
        }),
      security: [%{"oAuth" => ["write:notifications"]}],
      operationId: "PleromaAPI.NotificationController.mark_as_read",
      responses: %{
        200 =>
          Operation.response(
            "A Notification or array of Notifications",
            "application/json",
            %Schema{
              anyOf: [
                %Schema{type: :array, items: NotificationOperation.notification()},
                NotificationOperation.notification()
              ]
            }
          ),
        400 => Operation.response("Bad Request", "application/json", ApiError)
      }
    }
  end
end
