# Pleroma: A lightweight social networking server
# Copyright © 2017-2022 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.ApiSpec.Admin.MediaProxyCacheOperation do
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
      tags: ["MediaProxy cache"],
      summary: "Retrieve a list of banned MediaProxy URLs",
      operationId: "AdminAPI.MediaProxyCacheController.index",
      security: [%{"oAuth" => ["admin:read:media_proxy_caches"]}],
      parameters: [
        Operation.parameter(
          :query,
          :query,
          %Schema{type: :string, default: nil},
          "Page"
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
          Operation.response(
            "Array of MediaProxy URLs",
            "application/json",
            %Schema{
              type: :object,
              properties: %{
                count: %Schema{type: :integer},
                page_size: %Schema{type: :integer},
                urls: %Schema{
                  type: :array,
                  items: %Schema{
                    type: :string,
                    format: :uri,
                    description: "MediaProxy URLs"
                  }
                }
              }
            }
          )
      }
    }
  end

  def delete_operation do
    %Operation{
      tags: ["MediaProxy cache"],
      summary: "Remove a banned MediaProxy URL",
      operationId: "AdminAPI.MediaProxyCacheController.delete",
      security: [%{"oAuth" => ["admin:write:media_proxy_caches"]}],
      parameters: admin_api_params(),
      requestBody:
        request_body(
          "Parameters",
          %Schema{
            type: :object,
            required: [:urls],
            properties: %{
              urls: %Schema{type: :array, items: %Schema{type: :string, format: :uri}}
            }
          },
          required: true
        ),
      responses: %{
        200 => empty_object_response(),
        400 => Operation.response("Error", "application/json", ApiError)
      }
    }
  end

  def purge_operation do
    %Operation{
      tags: ["MediaProxy cache"],
      summary: "Purge a URL from MediaProxy cache and optionally ban it",
      operationId: "AdminAPI.MediaProxyCacheController.purge",
      security: [%{"oAuth" => ["admin:write:media_proxy_caches"]}],
      parameters: admin_api_params(),
      requestBody:
        request_body(
          "Parameters",
          %Schema{
            type: :object,
            required: [:urls],
            properties: %{
              urls: %Schema{type: :array, items: %Schema{type: :string, format: :uri}},
              ban: %Schema{type: :boolean, default: true}
            }
          },
          required: true
        ),
      responses: %{
        200 => empty_object_response(),
        400 => Operation.response("Error", "application/json", ApiError)
      }
    }
  end
end
