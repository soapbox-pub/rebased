# Pleroma: A lightweight social networking server
# Copyright © 2017-2021 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.ApiSpec.PleromaAppOperation do
  alias OpenApiSpex.Operation
  alias OpenApiSpex.Schema
  alias Pleroma.Web.ApiSpec.Schemas.App

  def open_api_operation(action) do
    operation = String.to_existing_atom("#{action}_operation")
    apply(__MODULE__, operation, [])
  end

  @spec index_operation() :: Operation.t()
  def index_operation do
    %Operation{
      tags: ["Applications"],
      summary: "List applications",
      description: "List the OAuth applications for the current user",
      operationId: "AppController.index",
      responses: %{
        200 => Operation.response("Array of App", "application/json", array_of_apps())
      }
    }
  end

  defp array_of_apps do
    %Schema{type: :array, items: App, example: [App.schema().example]}
  end
end
