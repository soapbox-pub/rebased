# Pleroma: A lightweight social networking server
# Copyright © 2017-2020 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.ApiSpec.AccountOperation do
  alias OpenApiSpex.Operation
  alias Pleroma.Web.ApiSpec.Schemas.AccountCreateRequest
  alias Pleroma.Web.ApiSpec.Schemas.AccountCreateResponse
  alias Pleroma.Web.ApiSpec.Helpers

  @spec open_api_operation(atom) :: Operation.t()
  def open_api_operation(action) do
    operation = String.to_existing_atom("#{action}_operation")
    apply(__MODULE__, operation, [])
  end

  @spec create_operation() :: Operation.t()
  def create_operation do
    %Operation{
      tags: ["accounts"],
      summary: "Register an account",
      description:
        "Creates a user and account records. Returns an account access token for the app that initiated the request. The app should save this token for later, and should wait for the user to confirm their account by clicking a link in their email inbox.",
      operationId: "AccountController.create",
      requestBody: Helpers.request_body("Parameters", AccountCreateRequest, required: true),
      responses: %{
        200 => Operation.response("Account", "application/json", AccountCreateResponse)
      }
    }
  end

  def verify_credentials_operation do
    :ok
  end

  def update_credentials_operation do
    :ok
  end

  def relationships_operation do
    :ok
  end

  def show_operation do
    :ok
  end

  def statuses_operation do
    :ok
  end

  def followers_operation do
    :ok
  end

  def following_operation, do: :ok
  def lists_operation, do: :ok
  def follow_operation, do: :ok
  def unfollow_operation, do: :ok
  def mute_operation, do: :ok
  def unmute_operation, do: :ok
  def block_operation, do: :ok
  def unblock_operation, do: :ok
  def follows_operation, do: :ok
  def mutes_operation, do: :ok
  def blocks_operation, do: :ok
  def endorsements_operation, do: :ok
end
