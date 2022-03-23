# Pleroma: A lightweight social networking server
# Copyright © 2017-2022 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.ApiSpec.UserImportOperation do
  alias OpenApiSpex.Operation
  alias OpenApiSpex.Schema
  alias Pleroma.Web.ApiSpec.Schemas.ApiError

  import Pleroma.Web.ApiSpec.Helpers

  @spec open_api_operation(atom) :: Operation.t()
  def open_api_operation(action) do
    operation = String.to_existing_atom("#{action}_operation")
    apply(__MODULE__, operation, [])
  end

  def follow_operation do
    %Operation{
      tags: ["Data import"],
      summary: "Import follows",
      operationId: "UserImportController.follow",
      requestBody: request_body("Parameters", import_request(), required: true),
      responses: %{
        200 => ok_response(),
        403 => Operation.response("Error", "application/json", ApiError),
        500 => Operation.response("Error", "application/json", ApiError)
      },
      security: [%{"oAuth" => ["write:follow"]}]
    }
  end

  def blocks_operation do
    %Operation{
      tags: ["Data import"],
      summary: "Import blocks",
      operationId: "UserImportController.blocks",
      requestBody: request_body("Parameters", import_request(), required: true),
      responses: %{
        200 => ok_response(),
        500 => Operation.response("Error", "application/json", ApiError)
      },
      security: [%{"oAuth" => ["write:blocks"]}]
    }
  end

  def mutes_operation do
    %Operation{
      tags: ["Data import"],
      summary: "Import mutes",
      operationId: "UserImportController.mutes",
      requestBody: request_body("Parameters", import_request(), required: true),
      responses: %{
        200 => ok_response(),
        500 => Operation.response("Error", "application/json", ApiError)
      },
      security: [%{"oAuth" => ["write:mutes"]}]
    }
  end

  defp import_request do
    %Schema{
      type: :object,
      required: [:list],
      properties: %{
        list: %Schema{
          description:
            "STRING or FILE containing a whitespace-separated list of accounts to import.",
          anyOf: [
            %Schema{type: :string, format: :binary},
            %Schema{type: :string}
          ]
        }
      }
    }
  end

  defp ok_response do
    Operation.response("Ok", "application/json", %Schema{type: :string, example: "ok"})
  end
end
