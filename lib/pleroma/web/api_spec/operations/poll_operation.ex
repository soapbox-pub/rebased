# Pleroma: A lightweight social networking server
# Copyright © 2017-2021 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.ApiSpec.PollOperation do
  alias OpenApiSpex.Operation
  alias OpenApiSpex.Schema
  alias Pleroma.Web.ApiSpec.Schemas.ApiError
  alias Pleroma.Web.ApiSpec.Schemas.FlakeID
  alias Pleroma.Web.ApiSpec.Schemas.Poll

  import Pleroma.Web.ApiSpec.Helpers

  def open_api_operation(action) do
    operation = String.to_existing_atom("#{action}_operation")
    apply(__MODULE__, operation, [])
  end

  def show_operation do
    %Operation{
      tags: ["Polls"],
      summary: "View a poll",
      security: [%{"oAuth" => ["read:statuses"]}],
      parameters: [id_param()],
      operationId: "PollController.show",
      responses: %{
        200 => Operation.response("Poll", "application/json", Poll),
        404 => Operation.response("Error", "application/json", ApiError)
      }
    }
  end

  def vote_operation do
    %Operation{
      tags: ["Polls"],
      summary: "Vote on a poll",
      parameters: [id_param()],
      operationId: "PollController.vote",
      requestBody: vote_request(),
      security: [%{"oAuth" => ["write:statuses"]}],
      responses: %{
        200 => Operation.response("Poll", "application/json", Poll),
        422 => Operation.response("Error", "application/json", ApiError),
        404 => Operation.response("Error", "application/json", ApiError)
      }
    }
  end

  defp id_param do
    Operation.parameter(:id, :path, FlakeID, "Poll ID",
      example: "123",
      required: true
    )
  end

  defp vote_request do
    request_body(
      "Parameters",
      %Schema{
        type: :object,
        properties: %{
          choices: %Schema{
            type: :array,
            items: %Schema{type: :integer},
            description: "Array of own votes containing index for each option (starting from 0)"
          }
        },
        required: [:choices]
      },
      required: true,
      example: %{
        "choices" => [0, 1, 2]
      }
    )
  end
end
