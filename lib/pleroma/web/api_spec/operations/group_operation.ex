# Pleroma: A lightweight social networking server
# Copyright © 2017-2021 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.ApiSpec.GroupOperation do
  alias OpenApiSpex.Operation
  alias OpenApiSpex.Schema
  alias Pleroma.Web.ApiSpec.AccountOperation
  alias Pleroma.Web.ApiSpec.Schemas.ApiError
  alias Pleroma.Web.ApiSpec.Schemas.BooleanLike
  alias Pleroma.Web.ApiSpec.Schemas.FlakeID
  alias Pleroma.Web.ApiSpec.Schemas.Group
  alias Pleroma.Web.ApiSpec.Schemas.GroupRelationship
  alias Pleroma.Web.ApiSpec.Schemas.PrivacyScope
  alias Pleroma.Web.ApiSpec.Schemas.ScheduledStatus
  alias Pleroma.Web.ApiSpec.Schemas.Status
  alias Pleroma.Web.ApiSpec.StatusOperation

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

  def show_operation do
    %Operation{
      tags: ["Retrieve group information"],
      summary: "Group",
      operationId: "GroupController.show",
      description: "View information about a group.",
      parameters: [id_param()],
      responses: %{
        200 => Operation.response("Group", "application/json", Group),
        401 => Operation.response("Error", "application/json", ApiError),
        404 => Operation.response("Error", "application/json", ApiError)
      }
    }
  end

  def join_operation do
    %Operation{
      tags: ["Group actions"],
      summary: "Join",
      operationId: "GroupController.join",
      security: [%{"oAuth" => ["memberships", "write:memberships"]}],
      description: "Join the given group",
      parameters: [id_param()],
      responses: %{
        200 => Operation.response("Relationship", "application/json", GroupRelationship),
        400 => Operation.response("Error", "application/json", ApiError),
        404 => Operation.response("Error", "application/json", ApiError)
      }
    }
  end

  def leave_operation do
    %Operation{
      tags: ["Group actions"],
      summary: "Leave",
      operationId: "GroupController.leave",
      security: [%{"oAuth" => ["memberships", "write:memberships"]}],
      description: "Leave the given group",
      parameters: [id_param()],
      responses: %{
        200 => Operation.response("Relationship", "application/json", GroupRelationship),
        400 => Operation.response("Error", "application/json", ApiError),
        404 => Operation.response("Error", "application/json", ApiError)
      }
    }
  end

  def relationships_operation do
    %Operation{
      tags: ["Retrieve group information"],
      summary: "Relationship between the logged in user and the given groups",
      operationId: "GroupController.relationships",
      description: "Find out whether the logged in user is a member, owner, etc. of the groups",
      security: [%{"oAuth" => ["read:memberships"]}],
      parameters: [
        Operation.parameter(
          :id,
          :query,
          %Schema{
            oneOf: [%Schema{type: :array, items: %Schema{type: :string}}, %Schema{type: :string}]
          },
          "Group IDs",
          example: "123"
        )
      ],
      responses: %{
        200 => Operation.response("Group", "application/json", array_of_relationships())
      }
    }
  end

  def statuses_operation do
    %Operation{
      summary: "Group",
      tags: ["Retrieve group information"],
      operationId: "GroupController.statuses",
      description:
        "Statuses posted to the given group. Public (for public statuses only), or user token + `read:statuses` (for private statuses the user is authorized to see)",
      parameters: [id_param()] ++ pagination_params(),
      responses: %{
        200 => Operation.response("Statuses", "application/json", array_of_statuses()),
        401 => Operation.response("Error", "application/json", ApiError),
        404 => Operation.response("Error", "application/json", ApiError)
      }
    }
  end

  def members_operation do
    %Operation{
      tags: ["Retrieve group information"],
      summary: "Members",
      operationId: "GroupController.members",
      security: [%{"oAuth" => ["read:accounts"]}],
      description:
        "Accounts which are members of the given group, if network is not hidden by the account owner.",
      parameters: [
        id_param(),
        Operation.parameter(:id, :query, :string, "ID of the resource owner"),
        with_relationships_param() | pagination_params()
      ],
      responses: %{
        200 =>
          Operation.response("Accounts", "application/json", AccountOperation.array_of_accounts())
      }
    }
  end

  def post_operation do
    %Operation{
      tags: ["Group actions"],
      summary: "Publish new status to the group",
      security: [%{"oAuth" => ["write:statuses"]}],
      description: "Post a new status to the group",
      operationId: "GroupController.post",
      parameters: [id_param()],
      requestBody: request_body("Parameters", status_create_request(), required: true),
      responses: %{
        200 =>
          Operation.response(
            "Status. When `scheduled_at` is present, ScheduledStatus is returned instead",
            "application/json",
            %Schema{anyOf: [Status, ScheduledStatus]}
          ),
        422 => Operation.response("Bad Request / MRF Rejection", "application/json", ApiError)
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

  defp status_create_request do
    %Schema{
      title: "GroupStatusCreateRequest",
      type: :object,
      properties: %{
        status: %Schema{
          type: :string,
          nullable: true,
          description:
            "Text content of the status. If `media_ids` is provided, this becomes optional. Attaching a `poll` is optional while `status` is provided."
        },
        media_ids: %Schema{
          nullable: true,
          type: :array,
          items: %Schema{type: :string},
          description: "Array of Attachment ids to be attached as media."
        },
        poll: StatusOperation.poll_params(),
        in_reply_to_id: %Schema{
          nullable: true,
          allOf: [FlakeID],
          description: "ID of the status being replied to, if status is a reply"
        },
        sensitive: %Schema{
          allOf: [BooleanLike],
          nullable: true,
          description: "Mark status and attached media as sensitive?"
        },
        spoiler_text: %Schema{
          type: :string,
          nullable: true,
          description:
            "Text to be shown as a warning or subject before the actual content. Statuses are generally collapsed behind this field."
        },
        language: %Schema{
          type: :string,
          nullable: true,
          description: "ISO 639 language code for this status."
        },
        # Pleroma-specific properties:
        preview: %Schema{
          allOf: [BooleanLike],
          nullable: true,
          description:
            "If set to `true` the post won't be actually posted, but the status entitiy would still be rendered back. This could be useful for previewing rich text/custom emoji, for example"
        },
        content_type: %Schema{
          type: :string,
          nullable: true,
          description:
            "The MIME type of the status, it is transformed into HTML by the backend. You can get the list of the supported MIME types with the nodeinfo endpoint."
        },
        to: %Schema{
          type: :array,
          nullable: true,
          items: %Schema{type: :string},
          description:
            "A list of nicknames (like `lain@soykaf.club` or `lain` on the local server) that will be used to determine who is going to be addressed by this post. Using this will disable the implicit addressing by mentioned names in the `status` body, only the people in the `to` list will be addressed. The normal rules for for post visibility are not affected by this and will still apply"
        },
        expires_in: %Schema{
          nullable: true,
          type: :integer,
          description:
            "The number of seconds the posted activity should expire in. When a posted activity expires it will be deleted from the server, and a delete request for it will be federated. This needs to be longer than an hour."
        },
        in_reply_to_conversation_id: %Schema{
          nullable: true,
          type: :string,
          description:
            "Will reply to a given conversation, addressing only the people who are part of the recipient set of that conversation. Sets the visibility to `direct`."
        }
      },
      example: %{
        "status" => "What time is it?",
        "sensitive" => "false",
        "poll" => %{
          "options" => ["Cofe", "Adventure"],
          "expires_in" => 420
        }
      }
    }
  end

  def id_param do
    Operation.parameter(:id, :path, FlakeID, "Group ID",
      example: "A8fI1zwFiqcRYXgBIu",
      required: true
    )
  end

  defp array_of_statuses do
    %Schema{
      title: "ArrayOfStatuses",
      type: :array,
      items: Status
    }
  end

  defp array_of_relationships do
    %Schema{
      title: "ArrayOfGroupRelationships",
      description: "Response schema for group relationships",
      type: :array,
      items: GroupRelationship,
      example: [
        %{
          "id" => "A8fI1zwFiqcRYXgBIu",
          "requested" => true,
          "member" => false,
          "owner" => false,
          "admin" => false,
          "moderator" => false
        },
        %{
          "id" => "A8n1lQ3ZVjOiUb6AUq",
          "requested" => false,
          "member" => true,
          "owner" => true,
          "admin" => true,
          "moderator" => false
        },
        %{
          "id" => "A8n1lgkLST7SFtEYO8",
          "requested" => false,
          "member" => true,
          "owner" => false,
          "admin" => false,
          "moderator" => true
        }
      ]
    }
  end
end
