# Pleroma: A lightweight social networking server
# Copyright © 2017-2021 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.ApiSpec.TwitterUtilOperation do
  alias OpenApiSpex.Operation
  alias OpenApiSpex.Schema
  alias Pleroma.Web.ApiSpec.Schemas.ApiError
  alias Pleroma.Web.ApiSpec.Schemas.BooleanLike

  def open_api_operation(action) do
    operation = String.to_existing_atom("#{action}_operation")
    apply(__MODULE__, operation, [])
  end

  def emoji_operation do
    %Operation{
      tags: ["Emojis"],
      summary: "List all custom emojis",
      operationId: "UtilController.emoji",
      parameters: [],
      responses: %{
        200 =>
          Operation.response("List", "application/json", %Schema{
            type: :object,
            additionalProperties: %Schema{
              type: :object,
              properties: %{
                image_url: %Schema{type: :string},
                tags: %Schema{type: :array, items: %Schema{type: :string}}
              }
            },
            example: %{
              "firefox" => %{
                "image_url" => "/emoji/firefox.png",
                "tag" => ["Fun"]
              }
            }
          })
      }
    }
  end

  def frontend_configurations_operation do
    %Operation{
      tags: ["Configuration"],
      summary: "Dump frontend configurations",
      operationId: "UtilController.frontend_configurations",
      parameters: [],
      responses: %{
        200 =>
          Operation.response("List", "application/json", %Schema{
            type: :object,
            additionalProperties: %Schema{type: :object}
          })
      }
    }
  end

  def change_password_operation do
    %Operation{
      tags: ["Account credentials"],
      summary: "Change account password",
      security: [%{"oAuth" => ["write:accounts"]}],
      operationId: "UtilController.change_password",
      parameters: [
        Operation.parameter(:password, :query, :string, "Current password", required: true),
        Operation.parameter(:new_password, :query, :string, "New password", required: true),
        Operation.parameter(
          :new_password_confirmation,
          :query,
          :string,
          "New password, confirmation",
          required: true
        )
      ],
      responses: %{
        200 =>
          Operation.response("Success", "application/json", %Schema{
            type: :object,
            properties: %{status: %Schema{type: :string, example: "success"}}
          }),
        400 => Operation.response("Error", "application/json", ApiError),
        403 => Operation.response("Error", "application/json", ApiError)
      }
    }
  end

  def change_email_operation do
    %Operation{
      tags: ["Account credentials"],
      summary: "Change account email",
      security: [%{"oAuth" => ["write:accounts"]}],
      operationId: "UtilController.change_email",
      parameters: [
        Operation.parameter(:password, :query, :string, "Current password", required: true),
        Operation.parameter(:email, :query, :string, "New email", required: true)
      ],
      requestBody: nil,
      responses: %{
        200 =>
          Operation.response("Success", "application/json", %Schema{
            type: :object,
            properties: %{status: %Schema{type: :string, example: "success"}}
          }),
        400 => Operation.response("Error", "application/json", ApiError),
        403 => Operation.response("Error", "application/json", ApiError)
      }
    }
  end

  def update_notificaton_settings_operation do
    %Operation{
      tags: ["Accounts"],
      summary: "Update Notification Settings",
      security: [%{"oAuth" => ["write:accounts"]}],
      operationId: "UtilController.update_notificaton_settings",
      parameters: [
        Operation.parameter(
          :block_from_strangers,
          :query,
          BooleanLike,
          "blocks notifications from accounts you do not follow"
        ),
        Operation.parameter(
          :hide_notification_contents,
          :query,
          BooleanLike,
          "removes the contents of a message from the push notification"
        )
      ],
      requestBody: nil,
      responses: %{
        200 =>
          Operation.response("Success", "application/json", %Schema{
            type: :object,
            properties: %{status: %Schema{type: :string, example: "success"}}
          }),
        400 => Operation.response("Error", "application/json", ApiError)
      }
    }
  end

  def disable_account_operation do
    %Operation{
      tags: ["Account credentials"],
      summary: "Disable Account",
      security: [%{"oAuth" => ["write:accounts"]}],
      operationId: "UtilController.disable_account",
      parameters: [
        Operation.parameter(:password, :query, :string, "Password")
      ],
      responses: %{
        200 =>
          Operation.response("Success", "application/json", %Schema{
            type: :object,
            properties: %{status: %Schema{type: :string, example: "success"}}
          }),
        403 => Operation.response("Error", "application/json", ApiError)
      }
    }
  end

  def delete_account_operation do
    %Operation{
      tags: ["Account credentials"],
      summary: "Delete Account",
      security: [%{"oAuth" => ["write:accounts"]}],
      operationId: "UtilController.delete_account",
      parameters: [
        Operation.parameter(:password, :query, :string, "Password")
      ],
      responses: %{
        200 =>
          Operation.response("Success", "application/json", %Schema{
            type: :object,
            properties: %{status: %Schema{type: :string, example: "success"}}
          }),
        403 => Operation.response("Error", "application/json", ApiError)
      }
    }
  end

  def captcha_operation do
    %Operation{
      summary: "Get a captcha",
      operationId: "UtilController.captcha",
      parameters: [],
      responses: %{
        200 => Operation.response("Success", "application/json", %Schema{type: :object})
      }
    }
  end

  def healthcheck_operation do
    %Operation{
      tags: ["Accounts"],
      summary: "Quick status check on the instance",
      security: [%{"oAuth" => ["write:accounts"]}],
      operationId: "UtilController.healthcheck",
      parameters: [],
      responses: %{
        200 => Operation.response("Healthy", "application/json", %Schema{type: :object}),
        503 =>
          Operation.response("Disabled or Unhealthy", "application/json", %Schema{type: :object})
      }
    }
  end

  def remote_subscribe_operation do
    %Operation{
      tags: ["Accounts"],
      summary: "Remote Subscribe",
      operationId: "UtilController.remote_subscribe",
      parameters: [],
      responses: %{200 => Operation.response("Web Page", "test/html", %Schema{type: :string})}
    }
  end
end
