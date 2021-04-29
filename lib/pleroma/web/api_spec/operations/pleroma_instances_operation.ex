# Pleroma: A lightweight social networking server
# Copyright © 2017-2021 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.ApiSpec.PleromaInstancesOperation do
  alias OpenApiSpex.Operation
  alias OpenApiSpex.Schema

  def open_api_operation(action) do
    operation = String.to_existing_atom("#{action}_operation")
    apply(__MODULE__, operation, [])
  end

  def show_operation do
    %Operation{
      tags: ["Instance"],
      summary: "Retrieve federation status",
      description: "Information about instances deemed unreachable by the server",
      operationId: "PleromaInstances.show",
      responses: %{
        200 => Operation.response("PleromaInstances", "application/json", pleroma_instances())
      }
    }
  end

  def pleroma_instances do
    %Schema{
      type: :object,
      properties: %{
        unreachable: %Schema{
          type: :object,
          properties: %{hostname: %Schema{type: :string, format: :"date-time"}}
        }
      },
      example: %{
        "unreachable" => %{"consistently-unreachable.name" => "2020-10-14 22:07:58.216473"}
      }
    }
  end
end
