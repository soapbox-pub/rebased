# Pleroma: A lightweight social networking server
# Copyright © 2017-2022 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.ApiSpec.PleromaStatusOperation do
  alias OpenApiSpex.Operation
  alias Pleroma.Web.ApiSpec.StatusOperation
  alias Pleroma.Web.ApiSpec.Schemas.ApiError
  alias Pleroma.Web.ApiSpec.Schemas.FlakeID

  import Pleroma.Web.ApiSpec.Helpers

  def open_api_operation(action) do
    operation = String.to_existing_atom("#{action}_operation")
    apply(__MODULE__, operation, [])
  end

  def quotes_operation do
    %Operation{
      tags: ["Retrieve status information"],
      summary: "Quoted by",
      description: "View quotes for a given status",
      operationId: "PleromaAPI.StatusController.quotes",
      parameters: [id_param() | pagination_params()],
      security: [%{"oAuth" => ["read:statuses"]}],
      responses: %{
        200 =>
          Operation.response(
            "Array of Status",
            "application/json",
            StatusOperation.array_of_statuses()
          ),
        403 => Operation.response("Forbidden", "application/json", ApiError),
        404 => Operation.response("Not Found", "application/json", ApiError)
      }
    }
  end

  def id_param do
    Operation.parameter(:id, :path, FlakeID, "Status ID",
      example: "9umDrYheeY451cQnEe",
      required: true
    )
  end
end
