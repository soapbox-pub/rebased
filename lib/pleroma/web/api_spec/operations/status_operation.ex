# Pleroma: A lightweight social networking server
# Copyright © 2017-2022 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.ApiSpec.StatusOperation do
  alias OpenApiSpex.Operation
  alias OpenApiSpex.Schema
  alias Pleroma.Web.ApiSpec.AccountOperation
  alias Pleroma.Web.ApiSpec.Schemas.Account
  alias Pleroma.Web.ApiSpec.Schemas.ApiError
  alias Pleroma.Web.ApiSpec.Schemas.Attachment
  alias Pleroma.Web.ApiSpec.Schemas.BooleanLike
  alias Pleroma.Web.ApiSpec.Schemas.Emoji
  alias Pleroma.Web.ApiSpec.Schemas.FlakeID
  alias Pleroma.Web.ApiSpec.Schemas.Poll
  alias Pleroma.Web.ApiSpec.Schemas.ScheduledStatus
  alias Pleroma.Web.ApiSpec.Schemas.Status
  alias Pleroma.Web.ApiSpec.Schemas.VisibilityScope

  import Pleroma.Web.ApiSpec.Helpers

  def open_api_operation(action) do
    operation = String.to_existing_atom("#{action}_operation")
    apply(__MODULE__, operation, [])
  end

  def index_operation do
    %Operation{
      tags: ["Retrieve status information"],
      summary: "Multiple statuses",
      security: [%{"oAuth" => ["read:statuses"]}],
      parameters: [
        Operation.parameter(
          :ids,
          :query,
          %Schema{type: :array, items: FlakeID},
          "Array of status IDs"
        ),
        Operation.parameter(
          :with_muted,
          :query,
          BooleanLike,
          "Include reactions from muted acccounts."
        )
      ],
      operationId: "StatusController.index",
      responses: %{
        200 => Operation.response("Array of Status", "application/json", array_of_statuses())
      }
    }
  end

  def create_operation do
    %Operation{
      tags: ["Status actions"],
      summary: "Publish new status",
      security: [%{"oAuth" => ["write:statuses"]}],
      description: "Post a new status",
      operationId: "StatusController.create",
      requestBody: request_body("Parameters", create_request(), required: true),
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

  def show_operation do
    %Operation{
      tags: ["Retrieve status information"],
      summary: "Status",
      description: "View information about a status",
      operationId: "StatusController.show",
      security: [%{"oAuth" => ["read:statuses"]}],
      parameters: [
        id_param(),
        Operation.parameter(
          :with_muted,
          :query,
          BooleanLike,
          "Include reactions from muted acccounts."
        )
      ],
      responses: %{
        200 => status_response(),
        404 => Operation.response("Not Found", "application/json", ApiError)
      }
    }
  end

  def delete_operation do
    %Operation{
      tags: ["Status actions"],
      summary: "Delete",
      security: [%{"oAuth" => ["write:statuses"]}],
      description: "Delete one of your own statuses",
      operationId: "StatusController.delete",
      parameters: [id_param()],
      responses: %{
        200 => status_response(),
        403 => Operation.response("Forbidden", "application/json", ApiError),
        404 => Operation.response("Not Found", "application/json", ApiError)
      }
    }
  end

  def reblog_operation do
    %Operation{
      tags: ["Status actions"],
      summary: "Reblog",
      security: [%{"oAuth" => ["write:statuses"]}],
      description: "Share a status",
      operationId: "StatusController.reblog",
      parameters: [id_param()],
      requestBody:
        request_body("Parameters", %Schema{
          type: :object,
          properties: %{
            visibility: %Schema{allOf: [VisibilityScope]}
          }
        }),
      responses: %{
        200 => status_response(),
        404 => Operation.response("Not Found", "application/json", ApiError)
      }
    }
  end

  def unreblog_operation do
    %Operation{
      tags: ["Status actions"],
      summary: "Undo reblog",
      security: [%{"oAuth" => ["write:statuses"]}],
      description: "Undo a reshare of a status",
      operationId: "StatusController.unreblog",
      parameters: [id_param()],
      responses: %{
        200 => status_response(),
        404 => Operation.response("Not Found", "application/json", ApiError)
      }
    }
  end

  def favourite_operation do
    %Operation{
      tags: ["Status actions"],
      summary: "Favourite",
      security: [%{"oAuth" => ["write:favourites"]}],
      description: "Add a status to your favourites list",
      operationId: "StatusController.favourite",
      parameters: [id_param()],
      responses: %{
        200 => status_response(),
        404 => Operation.response("Not Found", "application/json", ApiError)
      }
    }
  end

  def unfavourite_operation do
    %Operation{
      tags: ["Status actions"],
      summary: "Undo favourite",
      security: [%{"oAuth" => ["write:favourites"]}],
      description: "Remove a status from your favourites list",
      operationId: "StatusController.unfavourite",
      parameters: [id_param()],
      responses: %{
        200 => status_response(),
        404 => Operation.response("Not Found", "application/json", ApiError)
      }
    }
  end

  def pin_operation do
    %Operation{
      tags: ["Status actions"],
      summary: "Pin to profile",
      security: [%{"oAuth" => ["write:accounts"]}],
      description: "Feature one of your own public statuses at the top of your profile",
      operationId: "StatusController.pin",
      parameters: [id_param()],
      responses: %{
        200 => status_response(),
        400 =>
          Operation.response("Bad Request", "application/json", %Schema{
            allOf: [ApiError],
            title: "Unprocessable Entity",
            example: %{
              "error" => "You have already pinned the maximum number of statuses"
            }
          }),
        404 =>
          Operation.response("Not found", "application/json", %Schema{
            allOf: [ApiError],
            title: "Unprocessable Entity",
            example: %{
              "error" => "Record not found"
            }
          }),
        422 =>
          Operation.response(
            "Unprocessable Entity",
            "application/json",
            %Schema{
              allOf: [ApiError],
              title: "Unprocessable Entity",
              example: %{
                "error" => "Someone else's status cannot be pinned"
              }
            }
          )
      }
    }
  end

  def unpin_operation do
    %Operation{
      tags: ["Status actions"],
      summary: "Unpin from profile",
      security: [%{"oAuth" => ["write:accounts"]}],
      description: "Unfeature a status from the top of your profile",
      operationId: "StatusController.unpin",
      parameters: [id_param()],
      responses: %{
        200 => status_response(),
        400 =>
          Operation.response("Bad Request", "application/json", %Schema{
            allOf: [ApiError],
            title: "Unprocessable Entity",
            example: %{
              "error" => "You have already pinned the maximum number of statuses"
            }
          }),
        404 =>
          Operation.response("Not found", "application/json", %Schema{
            allOf: [ApiError],
            title: "Unprocessable Entity",
            example: %{
              "error" => "Record not found"
            }
          })
      }
    }
  end

  def bookmark_operation do
    %Operation{
      tags: ["Status actions"],
      summary: "Bookmark",
      security: [%{"oAuth" => ["write:bookmarks"]}],
      description: "Privately bookmark a status",
      operationId: "StatusController.bookmark",
      parameters: [id_param()],
      responses: %{
        200 => status_response()
      }
    }
  end

  def unbookmark_operation do
    %Operation{
      tags: ["Status actions"],
      summary: "Undo bookmark",
      security: [%{"oAuth" => ["write:bookmarks"]}],
      description: "Remove a status from your private bookmarks",
      operationId: "StatusController.unbookmark",
      parameters: [id_param()],
      responses: %{
        200 => status_response()
      }
    }
  end

  def mute_conversation_operation do
    %Operation{
      tags: ["Status actions"],
      summary: "Mute conversation",
      security: [%{"oAuth" => ["write:mutes"]}],
      description: "Do not receive notifications for the thread that this status is part of.",
      operationId: "StatusController.mute_conversation",
      requestBody:
        request_body("Parameters", %Schema{
          type: :object,
          properties: %{
            expires_in: %Schema{
              type: :integer,
              nullable: true,
              description: "Expire the mute in `expires_in` seconds. Default 0 for infinity",
              default: 0
            }
          }
        }),
      parameters: [
        id_param(),
        Operation.parameter(
          :expires_in,
          :query,
          %Schema{type: :integer, default: 0},
          "Expire the mute in `expires_in` seconds. Default 0 for infinity"
        )
      ],
      responses: %{
        200 => status_response(),
        400 => Operation.response("Error", "application/json", ApiError)
      }
    }
  end

  def unmute_conversation_operation do
    %Operation{
      tags: ["Status actions"],
      summary: "Unmute conversation",
      security: [%{"oAuth" => ["write:mutes"]}],
      description:
        "Start receiving notifications again for the thread that this status is part of",
      operationId: "StatusController.unmute_conversation",
      parameters: [id_param()],
      responses: %{
        200 => status_response(),
        400 => Operation.response("Error", "application/json", ApiError)
      }
    }
  end

  def card_operation do
    %Operation{
      tags: ["Retrieve status information"],
      deprecated: true,
      summary: "Preview card",
      description: "Deprecated in favor of card property inlined on Status entity",
      operationId: "StatusController.card",
      parameters: [id_param()],
      security: [%{"oAuth" => ["read:statuses"]}],
      responses: %{
        200 =>
          Operation.response("Card", "application/json", %Schema{
            type: :object,
            nullable: true,
            properties: %{
              type: %Schema{type: :string, enum: ["link", "photo", "video", "rich"]},
              provider_name: %Schema{type: :string, nullable: true},
              provider_url: %Schema{type: :string, format: :uri},
              url: %Schema{type: :string, format: :uri},
              image: %Schema{type: :string, nullable: true, format: :uri},
              title: %Schema{type: :string},
              description: %Schema{type: :string}
            }
          })
      }
    }
  end

  def favourited_by_operation do
    %Operation{
      tags: ["Retrieve status information"],
      summary: "Favourited by",
      description: "View who favourited a given status",
      operationId: "StatusController.favourited_by",
      security: [%{"oAuth" => ["read:accounts"]}],
      parameters: [id_param()],
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

  def reblogged_by_operation do
    %Operation{
      tags: ["Retrieve status information"],
      summary: "Reblogged by",
      description: "View who reblogged a given status",
      operationId: "StatusController.reblogged_by",
      security: [%{"oAuth" => ["read:accounts"]}],
      parameters: [id_param()],
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

  def context_operation do
    %Operation{
      tags: ["Retrieve status information"],
      summary: "Parent and child statuses",
      description: "View statuses above and below this status in the thread",
      operationId: "StatusController.context",
      security: [%{"oAuth" => ["read:statuses"]}],
      parameters: [id_param()],
      responses: %{
        200 => Operation.response("Context", "application/json", context())
      }
    }
  end

  def favourites_operation do
    %Operation{
      tags: ["Timelines"],
      summary: "Favourited statuses",
      description:
        "Statuses the user has favourited. Please note that you have to use the link headers to paginate this. You can not build the query parameters yourself.",
      operationId: "StatusController.favourites",
      parameters: pagination_params(),
      security: [%{"oAuth" => ["read:favourites"]}],
      responses: %{
        200 => Operation.response("Array of Statuses", "application/json", array_of_statuses())
      }
    }
  end

  def bookmarks_operation do
    %Operation{
      tags: ["Timelines"],
      summary: "Bookmarked statuses",
      description: "Statuses the user has bookmarked",
      operationId: "StatusController.bookmarks",
      parameters: pagination_params(),
      security: [%{"oAuth" => ["read:bookmarks"]}],
      responses: %{
        200 => Operation.response("Array of Statuses", "application/json", array_of_statuses())
      }
    }
  end

  def show_history_operation do
    %Operation{
      tags: ["Retrieve status history"],
      summary: "Status history",
      description: "View history of a status",
      operationId: "StatusController.show_history",
      security: [%{"oAuth" => ["read:statuses"]}],
      parameters: [
        id_param()
      ],
      responses: %{
        200 => status_history_response(),
        404 => Operation.response("Not Found", "application/json", ApiError)
      }
    }
  end

  def show_source_operation do
    %Operation{
      tags: ["Retrieve status source"],
      summary: "Status source",
      description: "View source of a status",
      operationId: "StatusController.show_source",
      security: [%{"oAuth" => ["read:statuses"]}],
      parameters: [
        id_param()
      ],
      responses: %{
        200 => status_source_response(),
        404 => Operation.response("Not Found", "application/json", ApiError)
      }
    }
  end

  def update_operation do
    %Operation{
      tags: ["Update status"],
      summary: "Update status",
      description: "Change the content of a status",
      operationId: "StatusController.update",
      security: [%{"oAuth" => ["write:statuses"]}],
      parameters: [
        id_param()
      ],
      requestBody: request_body("Parameters", update_request(), required: true),
      responses: %{
        200 => status_response(),
        403 => Operation.response("Forbidden", "application/json", ApiError),
        404 => Operation.response("Not Found", "application/json", ApiError)
      }
    }
  end

  def array_of_statuses do
    %Schema{type: :array, items: Status, example: [Status.schema().example]}
  end

  defp create_request do
    %Schema{
      title: "StatusCreateRequest",
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
        poll: poll_params(),
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
        scheduled_at: %Schema{
          type: :string,
          format: :"date-time",
          nullable: true,
          description:
            "ISO 8601 Datetime at which to schedule a status. Providing this paramter will cause ScheduledStatus to be returned instead of Status. Must be at least 5 minutes in the future."
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
        visibility: %Schema{
          nullable: true,
          anyOf: [
            VisibilityScope,
            %Schema{type: :string, description: "`list:LIST_ID`", example: "LIST:123"}
          ],
          description:
            "Visibility of the posted status. Besides standard MastoAPI values (`direct`, `private`, `unlisted` or `public`) it can be used to address a List by setting it to `list:LIST_ID`"
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

  defp update_request do
    %Schema{
      title: "StatusUpdateRequest",
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
        poll: poll_params(),
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

  def poll_params do
    %Schema{
      nullable: true,
      type: :object,
      required: [:options, :expires_in],
      properties: %{
        options: %Schema{
          type: :array,
          items: %Schema{type: :string},
          description: "Array of possible answers. Must be provided with `poll[expires_in]`."
        },
        expires_in: %Schema{
          type: :integer,
          nullable: true,
          description:
            "Duration the poll should be open, in seconds. Must be provided with `poll[options]`"
        },
        multiple: %Schema{
          allOf: [BooleanLike],
          nullable: true,
          description: "Allow multiple choices?"
        },
        hide_totals: %Schema{
          allOf: [BooleanLike],
          nullable: true,
          description: "Hide vote counts until the poll ends?"
        }
      }
    }
  end

  def id_param do
    Operation.parameter(:id, :path, FlakeID, "Status ID",
      example: "9umDrYheeY451cQnEe",
      required: true
    )
  end

  defp status_response do
    Operation.response("Status", "application/json", Status)
  end

  defp status_history_response do
    Operation.response(
      "Status History",
      "application/json",
      %Schema{
        title: "Status history",
        description: "Response schema for history of a status",
        type: :array,
        items: %Schema{
          type: :object,
          properties: %{
            account: %Schema{
              allOf: [Account],
              description: "The account that authored this status"
            },
            content: %Schema{
              type: :string,
              format: :html,
              description: "HTML-encoded status content"
            },
            sensitive: %Schema{
              type: :boolean,
              description: "Is this status marked as sensitive content?"
            },
            spoiler_text: %Schema{
              type: :string,
              description:
                "Subject or summary line, below which status content is collapsed until expanded"
            },
            created_at: %Schema{
              type: :string,
              format: "date-time",
              description: "The date when this status was created"
            },
            media_attachments: %Schema{
              type: :array,
              items: Attachment,
              description: "Media that is attached to this status"
            },
            emojis: %Schema{
              type: :array,
              items: Emoji,
              description: "Custom emoji to be used when rendering status content"
            },
            poll: %Schema{
              allOf: [Poll],
              nullable: true,
              description: "The poll attached to the status"
            }
          }
        }
      }
    )
  end

  defp status_source_response do
    Operation.response(
      "Status Source",
      "application/json",
      %Schema{
        type: :object,
        properties: %{
          id: FlakeID,
          text: %Schema{
            type: :string,
            description: "Raw source of status content"
          },
          spoiler_text: %Schema{
            type: :string,
            description:
              "Subject or summary line, below which status content is collapsed until expanded"
          },
          content_type: %Schema{
            type: :string,
            description: "The content type of the source"
          }
        }
      }
    )
  end

  defp context do
    %Schema{
      title: "StatusContext",
      description:
        "Represents the tree around a given status. Used for reconstructing threads of statuses.",
      type: :object,
      required: [:ancestors, :descendants],
      properties: %{
        ancestors: array_of_statuses(),
        descendants: array_of_statuses()
      },
      example: %{
        "ancestors" => [Status.schema().example],
        "descendants" => [Status.schema().example]
      }
    }
  end
end
