# Pleroma: A lightweight social networking server
# Copyright © 2017-2021 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.ApiSpec.Admin.FrontendOperation do
  alias OpenApiSpex.Operation
  alias OpenApiSpex.Schema
  alias Pleroma.Web.ApiSpec.Schemas.ApiError

  import Pleroma.Web.ApiSpec.Helpers

  def open_api_operation(action) do
    operation = String.to_existing_atom("#{action}_operation")
    apply(__MODULE__, operation, [])
  end

  def index_operation do
    %Operation{
      tags: ["Frontend managment"],
      summary: "Retrieve a list of available frontends",
      operationId: "AdminAPI.FrontendController.index",
      security: [%{"oAuth" => ["admin:read"]}],
      responses: %{
        200 => Operation.response("Response", "application/json", list_of_frontends()),
        403 => Operation.response("Forbidden", "application/json", ApiError)
      }
    }
  end

  def install_operation do
    %Operation{
      tags: ["Frontend managment"],
      summary: "Install a frontend",
      operationId: "AdminAPI.FrontendController.install",
      security: [%{"oAuth" => ["admin:read"]}],
      requestBody: request_body("Parameters", install_request(), required: true),
      responses: %{
        200 => Operation.response("Response", "application/json", list_of_frontends()),
        403 => Operation.response("Forbidden", "application/json", ApiError),
        400 => Operation.response("Error", "application/json", ApiError)
      }
    }
  end

  defp list_of_frontends do
    %Schema{
      type: :array,
      items: %Schema{
        type: :object,
        properties: %{
          name: %Schema{type: :string},
          git: %Schema{type: :string, format: :uri, nullable: true},
          build_url: %Schema{type: :string, format: :uri, nullable: true},
          ref: %Schema{type: :string},
          installed: %Schema{type: :boolean}
        }
      }
    }
  end

  defp install_request do
    %Schema{
      title: "FrontendInstallRequest",
      type: :object,
      required: [:name],
      properties: %{
        name: %Schema{
          type: :string
        },
        ref: %Schema{
          type: :string
        },
        file: %Schema{
          type: :string
        },
        build_url: %Schema{
          type: :string
        },
        build_dir: %Schema{
          type: :string
        }
      }
    }
  end
end
