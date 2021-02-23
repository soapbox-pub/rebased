# Pleroma: A lightweight social networking server
# Copyright © 2017-2021 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.ApiSpec.Admin.StatusOperation do
  alias OpenApiSpex.Operation
  alias OpenApiSpex.Schema
  alias Pleroma.Web.ApiSpec.Schemas.Account
  alias Pleroma.Web.ApiSpec.Schemas.ApiError
  alias Pleroma.Web.ApiSpec.Schemas.FlakeID
  alias Pleroma.Web.ApiSpec.Schemas.Status
  alias Pleroma.Web.ApiSpec.Schemas.VisibilityScope

  import Pleroma.Web.ApiSpec.Helpers
  import Pleroma.Web.ApiSpec.StatusOperation, only: [id_param: 0]

  def open_api_operation(action) do
    operation = String.to_existing_atom("#{action}_operation")
    apply(__MODULE__, operation, [])
  end

  def index_operation do
    %Operation{
      tags: ["Status administration"],
      operationId: "AdminAPI.StatusController.index",
      summary: "Get all statuses",
      security: [%{"oAuth" => ["admin:read:statuses"]}],
      parameters: [
        Operation.parameter(
          :godmode,
          :query,
          %Schema{type: :boolean, default: false},
          "Allows to see private statuses"
        ),
        Operation.parameter(
          :local_only,
          :query,
          %Schema{type: :boolean, default: false},
          "Excludes remote statuses"
        ),
        Operation.parameter(
          :with_reblogs,
          :query,
          %Schema{type: :boolean, default: false},
          "Allows to see reblogs"
        ),
        Operation.parameter(
          :page,
          :query,
          %Schema{type: :integer, default: 1},
          "Page"
        ),
        Operation.parameter(
          :page_size,
          :query,
          %Schema{type: :integer, default: 50},
          "Number of statuses to return"
        )
        | admin_api_params()
      ],
      responses: %{
        200 =>
          Operation.response("Array of statuses", "application/json", %Schema{
            type: :array,
            items: status()
          })
      }
    }
  end

  def show_operation do
    %Operation{
      tags: ["Status adminitration)"],
      summary: "Get status",
      operationId: "AdminAPI.StatusController.show",
      parameters: [id_param() | admin_api_params()],
      security: [%{"oAuth" => ["admin:read:statuses"]}],
      responses: %{
        200 => Operation.response("Status", "application/json", status()),
        404 => Operation.response("Not Found", "application/json", ApiError)
      }
    }
  end

  def update_operation do
    %Operation{
      tags: ["Status adminitration)"],
      summary: "Change the scope of a status",
      operationId: "AdminAPI.StatusController.update",
      parameters: [id_param() | admin_api_params()],
      security: [%{"oAuth" => ["admin:write:statuses"]}],
      requestBody: request_body("Parameters", update_request(), required: true),
      responses: %{
        200 => Operation.response("Status", "application/json", Status),
        400 => Operation.response("Error", "application/json", ApiError)
      }
    }
  end

  def delete_operation do
    %Operation{
      tags: ["Status adminitration)"],
      summary: "Delete status",
      operationId: "AdminAPI.StatusController.delete",
      parameters: [id_param() | admin_api_params()],
      security: [%{"oAuth" => ["admin:write:statuses"]}],
      responses: %{
        200 => empty_object_response(),
        404 => Operation.response("Not Found", "application/json", ApiError)
      }
    }
  end

  defp status do
    %Schema{
      anyOf: [
        Status,
        %Schema{
          type: :object,
          properties: %{
            account: %Schema{allOf: [Account, admin_account()]}
          }
        }
      ]
    }
  end

  def admin_account do
    %Schema{
      type: :object,
      properties: %{
        id: FlakeID,
        avatar: %Schema{type: :string},
        nickname: %Schema{type: :string},
        display_name: %Schema{type: :string},
        is_active: %Schema{type: :boolean},
        local: %Schema{type: :boolean},
        roles: %Schema{
          type: :object,
          properties: %{
            admin: %Schema{type: :boolean},
            moderator: %Schema{type: :boolean}
          }
        },
        tags: %Schema{type: :string},
        is_confirmed: %Schema{type: :string}
      }
    }
  end

  defp update_request do
    %Schema{
      type: :object,
      properties: %{
        sensitive: %Schema{
          type: :boolean,
          description: "Mark status and attached media as sensitive?"
        },
        visibility: VisibilityScope
      },
      example: %{
        "visibility" => "private",
        "sensitive" => "false"
      }
    }
  end
end
