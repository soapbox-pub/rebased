# Pleroma: A lightweight social networking server
# Copyright © 2017-2021 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.ApiSpec.PleromaAccountOperation do
  alias OpenApiSpex.Operation
  alias Pleroma.Web.ApiSpec.AccountOperation
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
      tags: ["Account credentials"],
      summary: "Resend confirmation email",
      description: "Expects `email` or `nickname`.",
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

  def favourites_operation do
    %Operation{
      tags: ["Retrieve account information"],
      summary: "Favorites",
      description:
        "Only returns data if the user has opted into sharing it. See `hide_favorites` in [Update account credentials](#operation/AccountController.update_credentials).",
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

  def endorsements_operation do
    %Operation{
      tags: ["Retrieve account information"],
      summary: "Endorsements",
      description: "Returns endorsed accounts",
      operationId: "PleromaAPI.AccountController.endorsements",
      parameters: [with_relationships_param(), id_param()],
      responses: %{
        200 =>
          Operation.response(
            "Array of Accounts",
            "application/json",
            AccountOperation.array_of_accounts()
          ),
        404 => Operation.response("Not Found", "application/json", ApiError)
      }
    }
  end

  def subscribe_operation do
    %Operation{
      tags: ["Account actions"],
      summary: "Subscribe",
      description: "Receive notifications for all statuses posted by the account.",
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
      tags: ["Account actions"],
      summary: "Unsubscribe",
      description: "Stop receiving notifications for all statuses posted by the account.",
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
end
