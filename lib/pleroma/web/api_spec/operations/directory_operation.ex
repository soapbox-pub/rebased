# Pleroma: A lightweight social networking server
# Copyright © 2017-2022 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.ApiSpec.DirectoryOperation do
  alias OpenApiSpex.Operation
  alias Pleroma.Web.ApiSpec.AccountOperation
  alias Pleroma.Web.ApiSpec.Schemas.ApiError
  alias Pleroma.Web.ApiSpec.Schemas.BooleanLike

  import Pleroma.Web.ApiSpec.Helpers

  def open_api_operation(action) do
    operation = String.to_existing_atom("#{action}_operation")
    apply(__MODULE__, operation, [])
  end

  def index_operation do
    %Operation{
      tags: ["Directory"],
      summary: "Profile directory",
      operationId: "DirectoryController.index",
      parameters:
        [
          Operation.parameter(
            :order,
            :query,
            :string,
            "Order by recent activity or account creation",
            required: nil
          ),
          Operation.parameter(:local, :query, BooleanLike, "Include local users only")
        ] ++ pagination_params(),
      responses: %{
        200 =>
          Operation.response("Accounts", "application/json", AccountOperation.array_of_accounts()),
        404 => Operation.response("Not Found", "application/json", ApiError)
      }
    }
  end
end
