# Pleroma: A lightweight social networking server
# Copyright © 2017-2022 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.ApiSpec.PleromaSettingsOperation do
  alias OpenApiSpex.Operation
  alias OpenApiSpex.Schema

  import Pleroma.Web.ApiSpec.Helpers

  def open_api_operation(action) do
    operation = String.to_existing_atom("#{action}_operation")
    apply(__MODULE__, operation, [])
  end

  def show_operation do
    %Operation{
      tags: ["Settings"],
      summary: "Get settings for an application",
      description: "Get synchronized settings for an application",
      operationId: "SettingsController.show",
      parameters: [app_name_param()],
      security: [%{"oAuth" => ["read:accounts"]}],
      responses: %{
        200 => Operation.response("object", "application/json", object())
      }
    }
  end

  def update_operation do
    %Operation{
      tags: ["Settings"],
      summary: "Update settings for an application",
      description: "Update synchronized settings for an application",
      operationId: "SettingsController.update",
      parameters: [app_name_param()],
      security: [%{"oAuth" => ["write:accounts"]}],
      requestBody: request_body("Parameters", update_request(), required: true),
      responses: %{
        200 => Operation.response("object", "application/json", object())
      }
    }
  end

  def app_name_param do
    Operation.parameter(:app, :path, %Schema{type: :string}, "Application name",
      example: "pleroma-fe",
      required: true
    )
  end

  def object do
    %Schema{
      title: "Settings object",
      description: "The object that contains settings for the application.",
      type: :object
    }
  end

  def update_request do
    %Schema{
      title: "SettingsUpdateRequest",
      type: :object,
      description:
        "The settings object to be merged with the current settings. To remove a field, set it to null.",
      example: %{
        "config1" => true,
        "config2_to_unset" => nil
      }
    }
  end
end
