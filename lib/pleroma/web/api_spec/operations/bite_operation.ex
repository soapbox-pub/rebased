# Pleroma: A lightweight social networking server
# Copyright © 2017-2024 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.ApiSpec.BiteOperation do
  alias OpenApiSpex.Operation
  alias OpenApiSpex.Schema
  alias Pleroma.Web.ApiSpec.Schemas.ApiError

  @spec open_api_operation(atom) :: Operation.t()
  def open_api_operation(action) do
    operation = String.to_existing_atom("#{action}_operation")
    apply(__MODULE__, operation, [])
  end

  def bite_operation do
    %Operation{
      tags: ["Bites"],
      summary: "Bite",
      operationId: "BiteController.bite",
      security: [%{"oAuth" => ["write:bites"]}],
      description: "Bite the given account",
      parameters: [
        Operation.parameter(:id, :query, :string, "Bitten account ID")
      ],
      responses: %{
        200 => Operation.response("Empty object", "application/json", %Schema{type: :object}),
        400 => Operation.response("Error", "application/json", ApiError),
        404 => Operation.response("Error", "application/json", ApiError)
      }
    }
  end
end
