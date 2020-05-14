# Pleroma: A lightweight social networking server
# Copyright © 2017-2020 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.ApiSpec.PleromaAccountOperation do
  alias OpenApiSpex.Operation
  alias OpenApiSpex.Schema
  alias Pleroma.Web.ApiSpec.Schemas.AccountRelationship
  alias Pleroma.Web.ApiSpec.Schemas.ApiError
  alias Pleroma.Web.ApiSpec.Schemas.FlakeID
  alias Pleroma.Web.ApiSpec.StatusOperation

  import Pleroma.Web.ApiSpec.Helpers

  def open_api_operation(action) do
    operation = String.to_existing_atom("#{action}_operation")
    apply(__MODULE__, operation, [])
  end

  def confirmation_resend_operation do
    %Operation{
      tags: ["Accounts"],
      summary: "Resend confirmation email. Expects `email` or `nickname`",
      operationId: "PleromaAPI.AccountController.confirmation_resend",
      parameters: [
        Operation.parameter(:email, :query, :string, "Email of that needs to be verified",
          example: "cofe@cofe.io"
        ),
        Operation.parameter(
          :nickname,
          :query,
          :string,
          "Nickname of user that needs to be verified",
          example: "cofefe"
        )
      ],
      responses: %{
        204 => no_content_response()
      }
    }
  end

  def update_avatar_operation do
    %Operation{
      tags: ["Accounts"],
      summary: "Set/clear user avatar image",
      operationId: "PleromaAPI.AccountController.update_avatar",
      requestBody:
        request_body("Parameters", update_avatar_or_background_request(), required: true),
      security: [%{"oAuth" => ["write:accounts"]}],
      responses: %{
        200 => update_response(),
        403 => Operation.response("Forbidden", "application/json", ApiError)
      }
    }
  end

  def update_banner_operation do
    %Operation{
      tags: ["Accounts"],
      summary: "Set/clear user banner image",
      operationId: "PleromaAPI.AccountController.update_banner",
      requestBody: request_body("Parameters", update_banner_request(), required: true),
      security: [%{"oAuth" => ["write:accounts"]}],
      responses: %{
        200 => update_response()
      }
    }
  end

  def update_background_operation do
    %Operation{
      tags: ["Accounts"],
      summary: "Set/clear user background image",
      operationId: "PleromaAPI.AccountController.update_background",
      security: [%{"oAuth" => ["write:accounts"]}],
      requestBody:
        request_body("Parameters", update_avatar_or_background_request(), required: true),
      responses: %{
        200 => update_response()
      }
    }
  end

  def favourites_operation do
    %Operation{
      tags: ["Accounts"],
      summary: "Returns favorites timeline of any user",
      operationId: "PleromaAPI.AccountController.favourites",
      parameters: [id_param() | pagination_params()],
      security: [%{"oAuth" => ["read:favourites"]}],
      responses: %{
        200 =>
          Operation.response(
            "Array of Statuses",
            "application/json",
            StatusOperation.array_of_statuses()
          ),
        403 => Operation.response("Forbidden", "application/json", ApiError),
        404 => Operation.response("Not Found", "application/json", ApiError)
      }
    }
  end

  def subscribe_operation do
    %Operation{
      tags: ["Accounts"],
      summary: "Subscribe to receive notifications for all statuses posted by a user",
      operationId: "PleromaAPI.AccountController.subscribe",
      parameters: [id_param()],
      security: [%{"oAuth" => ["follow", "write:follows"]}],
      responses: %{
        200 => Operation.response("Relationship", "application/json", AccountRelationship),
        404 => Operation.response("Not Found", "application/json", ApiError)
      }
    }
  end

  def unsubscribe_operation do
    %Operation{
      tags: ["Accounts"],
      summary: "Unsubscribe to stop receiving notifications from user statuses¶",
      operationId: "PleromaAPI.AccountController.unsubscribe",
      parameters: [id_param()],
      security: [%{"oAuth" => ["follow", "write:follows"]}],
      responses: %{
        200 => Operation.response("Relationship", "application/json", AccountRelationship),
        404 => Operation.response("Not Found", "application/json", ApiError)
      }
    }
  end

  defp id_param do
    Operation.parameter(:id, :path, FlakeID, "Account ID",
      example: "9umDrYheeY451cQnEe",
      required: true
    )
  end

  defp update_avatar_or_background_request do
    %Schema{
      title: "PleromaAccountUpdateAvatarOrBackgroundRequest",
      type: :object,
      properties: %{
        img: %Schema{
          type: :string,
          format: :binary,
          description: "Image encoded using `multipart/form-data` or an empty string to clear"
        }
      }
    }
  end

  defp update_banner_request do
    %Schema{
      title: "PleromaAccountUpdateBannerRequest",
      type: :object,
      properties: %{
        banner: %Schema{
          type: :string,
          format: :binary,
          description: "Image encoded using `multipart/form-data` or an empty string to clear"
        }
      }
    }
  end

  defp update_response do
    Operation.response("PleromaAccountUpdateResponse", "application/json", %Schema{
      type: :object,
      properties: %{
        url: %Schema{
          type: :string,
          format: :uri,
          nullable: true,
          description: "Image URL"
        }
      },
      example: %{
        "url" =>
          "https://cofe.party/media/9d0add56-bcb6-4c0f-8225-cbbd0b6dd773/13eadb6972c9ccd3f4ffa3b8196f0e0d38b4d2f27594457c52e52946c054cd9a.gif"
      }
    })
  end
end
