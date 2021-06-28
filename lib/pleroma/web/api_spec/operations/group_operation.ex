# Pleroma: A lightweight social networking server
# Copyright © 2017-2021 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.ApiSpec.GroupOperation do
  alias OpenApiSpex.Operation
  alias OpenApiSpex.Schema
  alias Pleroma.Web.ApiSpec.Schemas.ApiError
  alias Pleroma.Web.ApiSpec.Schemas.BooleanLike
  alias Pleroma.Web.ApiSpec.Schemas.Group
  alias Pleroma.Web.ApiSpec.Schemas.PrivacyScope

  import Pleroma.Web.ApiSpec.Helpers

  @spec open_api_operation(atom) :: Operation.t()
  def open_api_operation(action) do
    operation = String.to_existing_atom("#{action}_operation")
    apply(__MODULE__, operation, [])
  end

  @spec create_operation() :: Operation.t()
  def create_operation do
    %Operation{
      tags: ["Group"],
      summary: "Create a group",
      description: "Creates a group account with the specified privacy setting.",
      operationId: "GroupController.create",
      requestBody: request_body("Parameters", create_request(), required: true),
      responses: %{
        200 => Operation.response("Group", "application/json", Group),
        400 => Operation.response("Error", "application/json", ApiError),
        403 => Operation.response("Error", "application/json", ApiError),
        429 => Operation.response("Error", "application/json", ApiError)
      }
    }
  end

  defp create_request do
    %Schema{
      title: "GroupCreateRequest",
      description: "POST body for creating a group",
      type: :object,
      required: [:slug],
      properties: %{
        slug: %Schema{
          type: :string,
          description:
            "The desired slug for the group. A slug is like a username: it is displayed in URLs, and groups can be mentioned by their slug. Slugs share the same namespace as usernames on an instance. Only alphanumeric characters, hyphens, and underscores are allowed. This name cannot be changed later."
        },
        display_name: %Schema{
          type: :string,
          nullable: true,
          description:
            "Pretty name of the group for display purposes. Special characters are allowed, and it can be changed later."
        },
        note: %Schema{
          type: :string,
          description: "An explanation of what this group does and who it's for.",
          nullable: true,
          default: ""
        },
        locked: %Schema{
          allOf: [BooleanLike],
          nullable: true,
          description: "Whether manual approval of join requests is required."
        },
        privacy: PrivacyScope
      },
      example: %{
        "slug" => "dogelovers",
        "display_name" => "Doge Lovers of Fedi",
        "note" => "The Fediverse's largest meme group. Join to laugh and have fun.",
        "locked" => "false",
        "privacy" => "public"
      }
    }
  end
end
