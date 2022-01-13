# Pleroma: A lightweight social networking server
# Copyright © 2017-2021 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.ApiSpec.AccountOperation do
  alias OpenApiSpex.Operation
  alias OpenApiSpex.Reference
  alias OpenApiSpex.Schema
  alias Pleroma.Web.ApiSpec.Schemas.Account
  alias Pleroma.Web.ApiSpec.Schemas.AccountRelationship
  alias Pleroma.Web.ApiSpec.Schemas.ActorType
  alias Pleroma.Web.ApiSpec.Schemas.ApiError
  alias Pleroma.Web.ApiSpec.Schemas.BooleanLike
  alias Pleroma.Web.ApiSpec.Schemas.List
  alias Pleroma.Web.ApiSpec.Schemas.Status
  alias Pleroma.Web.ApiSpec.Schemas.VisibilityScope

  import Pleroma.Web.ApiSpec.Helpers

  @spec open_api_operation(atom) :: Operation.t()
  def open_api_operation(action) do
    operation = String.to_existing_atom("#{action}_operation")
    apply(__MODULE__, operation, [])
  end

  @spec create_operation() :: Operation.t()
  def create_operation do
    %Operation{
      tags: ["Account credentials"],
      summary: "Register an account",
      description:
        "Creates a user and account records. Returns an account access token for the app that initiated the request. The app should save this token for later, and should wait for the user to confirm their account by clicking a link in their email inbox.",
      operationId: "AccountController.create",
      requestBody: request_body("Parameters", create_request(), required: true),
      responses: %{
        200 => Operation.response("Account", "application/json", create_response()),
        400 => Operation.response("Error", "application/json", ApiError),
        403 => Operation.response("Error", "application/json", ApiError),
        429 => Operation.response("Error", "application/json", ApiError)
      }
    }
  end

  def verify_credentials_operation do
    %Operation{
      tags: ["Account credentials"],
      description: "Test to make sure that the user token works.",
      summary: "Verify account credentials",
      operationId: "AccountController.verify_credentials",
      security: [%{"oAuth" => ["read:accounts"]}],
      responses: %{
        200 => Operation.response("Account", "application/json", Account)
      }
    }
  end

  def update_credentials_operation do
    %Operation{
      tags: ["Account credentials"],
      summary: "Update account credentials",
      description: "Update the user's display and preferences.",
      operationId: "AccountController.update_credentials",
      security: [%{"oAuth" => ["write:accounts"]}],
      requestBody: request_body("Parameters", update_credentials_request(), required: true),
      responses: %{
        200 => Operation.response("Account", "application/json", Account),
        403 => Operation.response("Error", "application/json", ApiError)
      }
    }
  end

  def relationships_operation do
    %Operation{
      tags: ["Retrieve account information"],
      summary: "Relationship with current account",
      operationId: "AccountController.relationships",
      description: "Find out whether a given account is followed, blocked, muted, etc.",
      security: [%{"oAuth" => ["read:follows"]}],
      parameters: [
        Operation.parameter(
          :id,
          :query,
          %Schema{
            oneOf: [%Schema{type: :array, items: %Schema{type: :string}}, %Schema{type: :string}]
          },
          "Account IDs",
          example: "123"
        )
      ],
      responses: %{
        200 => Operation.response("Account", "application/json", array_of_relationships())
      }
    }
  end

  def show_operation do
    %Operation{
      tags: ["Retrieve account information"],
      summary: "Account",
      operationId: "AccountController.show",
      description: "View information about a profile.",
      parameters: [
        %Reference{"$ref": "#/components/parameters/accountIdOrNickname"},
        with_relationships_param()
      ],
      responses: %{
        200 => Operation.response("Account", "application/json", Account),
        401 => Operation.response("Error", "application/json", ApiError),
        404 => Operation.response("Error", "application/json", ApiError)
      }
    }
  end

  def statuses_operation do
    %Operation{
      summary: "Statuses",
      tags: ["Retrieve account information"],
      operationId: "AccountController.statuses",
      description:
        "Statuses posted to the given account. Public (for public statuses only), or user token + `read:statuses` (for private statuses the user is authorized to see)",
      parameters:
        [
          %Reference{"$ref": "#/components/parameters/accountIdOrNickname"},
          Operation.parameter(:pinned, :query, BooleanLike, "Include only pinned statuses"),
          Operation.parameter(:tagged, :query, :string, "With tag"),
          Operation.parameter(
            :only_media,
            :query,
            BooleanLike,
            "Include only statuses with media attached"
          ),
          Operation.parameter(
            :with_muted,
            :query,
            BooleanLike,
            "Include statuses from muted accounts."
          ),
          Operation.parameter(:exclude_reblogs, :query, BooleanLike, "Exclude reblogs"),
          Operation.parameter(:exclude_replies, :query, BooleanLike, "Exclude replies"),
          Operation.parameter(
            :exclude_visibilities,
            :query,
            %Schema{type: :array, items: VisibilityScope},
            "Exclude visibilities"
          ),
          Operation.parameter(
            :with_muted,
            :query,
            BooleanLike,
            "Include reactions from muted accounts."
          )
        ] ++ pagination_params(),
      responses: %{
        200 => Operation.response("Statuses", "application/json", array_of_statuses()),
        401 => Operation.response("Error", "application/json", ApiError),
        404 => Operation.response("Error", "application/json", ApiError)
      }
    }
  end

  def followers_operation do
    %Operation{
      tags: ["Retrieve account information"],
      summary: "Followers",
      operationId: "AccountController.followers",
      security: [%{"oAuth" => ["read:accounts"]}],
      description:
        "Accounts which follow the given account, if network is not hidden by the account owner.",
      parameters: [
        %Reference{"$ref": "#/components/parameters/accountIdOrNickname"},
        Operation.parameter(:id, :query, :string, "ID of the resource owner"),
        with_relationships_param() | pagination_params()
      ],
      responses: %{
        200 => Operation.response("Accounts", "application/json", array_of_accounts())
      }
    }
  end

  def following_operation do
    %Operation{
      tags: ["Retrieve account information"],
      summary: "Following",
      operationId: "AccountController.following",
      security: [%{"oAuth" => ["read:accounts"]}],
      description:
        "Accounts which the given account is following, if network is not hidden by the account owner.",
      parameters: [
        %Reference{"$ref": "#/components/parameters/accountIdOrNickname"},
        Operation.parameter(:id, :query, :string, "ID of the resource owner"),
        with_relationships_param() | pagination_params()
      ],
      responses: %{200 => Operation.response("Accounts", "application/json", array_of_accounts())}
    }
  end

  def lists_operation do
    %Operation{
      tags: ["Retrieve account information"],
      summary: "Lists containing this account",
      operationId: "AccountController.lists",
      security: [%{"oAuth" => ["read:lists"]}],
      description: "User lists that you have added this account to.",
      parameters: [%Reference{"$ref": "#/components/parameters/accountIdOrNickname"}],
      responses: %{200 => Operation.response("Lists", "application/json", array_of_lists())}
    }
  end

  def follow_operation do
    %Operation{
      tags: ["Account actions"],
      summary: "Follow",
      operationId: "AccountController.follow",
      security: [%{"oAuth" => ["follow", "write:follows"]}],
      description: "Follow the given account",
      parameters: [
        %Reference{"$ref": "#/components/parameters/accountIdOrNickname"}
      ],
      requestBody:
        request_body(
          "Parameters",
          %Schema{
            type: :object,
            properties: %{
              reblogs: %Schema{
                type: :boolean,
                description: "Receive this account's reblogs in home timeline? Defaults to true.",
                default: true
              },
              notify: %Schema{
                type: :boolean,
                description:
                  "Receive notifications for all statuses posted by the account? Defaults to false.",
                default: false
              }
            }
          },
          required: false
        ),
      responses: %{
        200 => Operation.response("Relationship", "application/json", AccountRelationship),
        400 => Operation.response("Error", "application/json", ApiError),
        404 => Operation.response("Error", "application/json", ApiError)
      }
    }
  end

  def unfollow_operation do
    %Operation{
      tags: ["Account actions"],
      summary: "Unfollow",
      operationId: "AccountController.unfollow",
      security: [%{"oAuth" => ["follow", "write:follows"]}],
      description: "Unfollow the given account",
      parameters: [%Reference{"$ref": "#/components/parameters/accountIdOrNickname"}],
      responses: %{
        200 => Operation.response("Relationship", "application/json", AccountRelationship),
        400 => Operation.response("Error", "application/json", ApiError),
        404 => Operation.response("Error", "application/json", ApiError)
      }
    }
  end

  def mute_operation do
    %Operation{
      tags: ["Account actions"],
      summary: "Mute",
      operationId: "AccountController.mute",
      security: [%{"oAuth" => ["follow", "write:mutes"]}],
      requestBody: request_body("Parameters", mute_request()),
      description:
        "Mute the given account. Clients should filter statuses and notifications from this account, if received (e.g. due to a boost in the Home timeline).",
      parameters: [
        %Reference{"$ref": "#/components/parameters/accountIdOrNickname"},
        Operation.parameter(
          :notifications,
          :query,
          %Schema{allOf: [BooleanLike], default: true},
          "Mute notifications in addition to statuses? Defaults to `true`."
        ),
        Operation.parameter(
          :expires_in,
          :query,
          %Schema{type: :integer, default: 0},
          "Expire the mute in `expires_in` seconds. Default 0 for infinity"
        )
      ],
      responses: %{
        200 => Operation.response("Relationship", "application/json", AccountRelationship)
      }
    }
  end

  def unmute_operation do
    %Operation{
      tags: ["Account actions"],
      summary: "Unmute",
      operationId: "AccountController.unmute",
      security: [%{"oAuth" => ["follow", "write:mutes"]}],
      description: "Unmute the given account.",
      parameters: [%Reference{"$ref": "#/components/parameters/accountIdOrNickname"}],
      responses: %{
        200 => Operation.response("Relationship", "application/json", AccountRelationship)
      }
    }
  end

  def block_operation do
    %Operation{
      tags: ["Account actions"],
      summary: "Block",
      operationId: "AccountController.block",
      security: [%{"oAuth" => ["follow", "write:blocks"]}],
      description:
        "Block the given account. Clients should filter statuses from this account if received (e.g. due to a boost in the Home timeline)",
      parameters: [%Reference{"$ref": "#/components/parameters/accountIdOrNickname"}],
      responses: %{
        200 => Operation.response("Relationship", "application/json", AccountRelationship)
      }
    }
  end

  def unblock_operation do
    %Operation{
      tags: ["Account actions"],
      summary: "Unblock",
      operationId: "AccountController.unblock",
      security: [%{"oAuth" => ["follow", "write:blocks"]}],
      description: "Unblock the given account.",
      parameters: [%Reference{"$ref": "#/components/parameters/accountIdOrNickname"}],
      responses: %{
        200 => Operation.response("Relationship", "application/json", AccountRelationship)
      }
    }
  end

  def endorse_operation do
    %Operation{
      tags: ["Account actions"],
      summary: "Endorse",
      operationId: "AccountController.endorse",
      security: [%{"oAuth" => ["follow", "write:accounts"]}],
      description: "Addds the given account to endorsed accounts list.",
      parameters: [%Reference{"$ref": "#/components/parameters/accountIdOrNickname"}],
      responses: %{
        200 => Operation.response("Relationship", "application/json", AccountRelationship),
        400 =>
          Operation.response("Bad Request", "application/json", %Schema{
            allOf: [ApiError],
            title: "Unprocessable Entity",
            example: %{
              "error" => "You have already pinned the maximum number of users"
            }
          })
      }
    }
  end

  def unendorse_operation do
    %Operation{
      tags: ["Account actions"],
      summary: "Unendorse",
      operationId: "AccountController.unendorse",
      security: [%{"oAuth" => ["follow", "write:accounts"]}],
      description: "Removes the given account from endorsed accounts list.",
      parameters: [%Reference{"$ref": "#/components/parameters/accountIdOrNickname"}],
      responses: %{
        200 => Operation.response("Relationship", "application/json", AccountRelationship)
      }
    }
  end

  def note_operation do
    %Operation{
      tags: ["Account actions"],
      summary: "Set a private note about a user.",
      operationId: "AccountController.note",
      security: [%{"oAuth" => ["follow", "write:accounts"]}],
      requestBody: request_body("Parameters", note_request()),
      description: "Create a note for the given account.",
      parameters: [
        %Reference{"$ref": "#/components/parameters/accountIdOrNickname"},
        Operation.parameter(
          :comment,
          :query,
          %Schema{type: :string},
          "Account note body"
        )
      ],
      responses: %{
        200 => Operation.response("Relationship", "application/json", AccountRelationship)
      }
    }
  end

  def follow_by_uri_operation do
    %Operation{
      tags: ["Account actions"],
      summary: "Follow by URI",
      operationId: "AccountController.follows",
      security: [%{"oAuth" => ["follow", "write:follows"]}],
      requestBody: request_body("Parameters", follow_by_uri_request(), required: true),
      responses: %{
        200 => Operation.response("Account", "application/json", AccountRelationship),
        400 => Operation.response("Error", "application/json", ApiError),
        404 => Operation.response("Error", "application/json", ApiError)
      }
    }
  end

  def mutes_operation do
    %Operation{
      tags: ["Blocks and mutes"],
      summary: "Retrieve list of mutes",
      operationId: "AccountController.mutes",
      description: "Accounts the user has muted.",
      security: [%{"oAuth" => ["follow", "read:mutes"]}],
      parameters: [with_relationships_param() | pagination_params()],
      responses: %{
        200 => Operation.response("Accounts", "application/json", array_of_accounts())
      }
    }
  end

  def blocks_operation do
    %Operation{
      tags: ["Blocks and mutes"],
      summary: "Retrieve list of blocks",
      operationId: "AccountController.blocks",
      description: "View your blocks. See also accounts/:id/{block,unblock}",
      security: [%{"oAuth" => ["read:blocks"]}],
      parameters: pagination_params(),
      responses: %{
        200 => Operation.response("Accounts", "application/json", array_of_accounts())
      }
    }
  end

  def lookup_operation do
    %Operation{
      tags: ["Account lookup"],
      summary: "Find a user by nickname",
      operationId: "AccountController.lookup",
      parameters: [
        Operation.parameter(
          :acct,
          :query,
          :string,
          "User nickname"
        )
      ],
      responses: %{
        200 => Operation.response("Account", "application/json", Account),
        404 => Operation.response("Error", "application/json", ApiError)
      }
    }
  end

  def endorsements_operation do
    %Operation{
      tags: ["Retrieve account information"],
      summary: "Endorsements",
      operationId: "AccountController.endorsements",
      description: "Returns endorsed accounts",
      security: [%{"oAuth" => ["read:accounts"]}],
      responses: %{
        200 => Operation.response("Array of Accounts", "application/json", array_of_accounts())
      }
    }
  end

  def identity_proofs_operation do
    %Operation{
      tags: ["Retrieve account information"],
      summary: "Identity proofs",
      operationId: "AccountController.identity_proofs",
      # Validators complains about unused path params otherwise
      parameters: [
        %Reference{"$ref": "#/components/parameters/accountIdOrNickname"}
      ],
      description: "Not implemented",
      responses: %{
        200 => empty_array_response()
      }
    }
  end

  defp create_request do
    %Schema{
      title: "AccountCreateRequest",
      description: "POST body for creating an account",
      type: :object,
      required: [:username, :password, :agreement],
      properties: %{
        reason: %Schema{
          type: :string,
          nullable: true,
          description:
            "Text that will be reviewed by moderators if registrations require manual approval"
        },
        username: %Schema{type: :string, description: "The desired username for the account"},
        email: %Schema{
          type: :string,
          nullable: true,
          description:
            "The email address to be used for login. Required when `account_activation_required` is enabled.",
          format: :email
        },
        password: %Schema{
          type: :string,
          description: "The password to be used for login",
          format: :password
        },
        agreement: %Schema{
          allOf: [BooleanLike],
          description:
            "Whether the user agrees to the local rules, terms, and policies. These should be presented to the user in order to allow them to consent before setting this parameter to TRUE."
        },
        locale: %Schema{
          type: :string,
          nullable: true,
          description: "The language of the confirmation email that will be sent"
        },
        # Pleroma-specific properties:
        fullname: %Schema{type: :string, nullable: true, description: "Full name"},
        bio: %Schema{type: :string, description: "Bio", nullable: true, default: ""},
        captcha_solution: %Schema{
          type: :string,
          nullable: true,
          description: "Provider-specific captcha solution"
        },
        captcha_token: %Schema{
          type: :string,
          nullable: true,
          description: "Provider-specific captcha token"
        },
        captcha_answer_data: %Schema{
          type: :string,
          nullable: true,
          description: "Provider-specific captcha data"
        },
        token: %Schema{
          type: :string,
          nullable: true,
          description: "Invite token required when the registrations aren't public"
        }
      },
      example: %{
        "username" => "cofe",
        "email" => "cofe@example.com",
        "password" => "secret",
        "agreement" => "true",
        "bio" => "☕️"
      }
    }
  end

  # Note: this is a token response (if login succeeds!), but there's no oauth operation file yet.
  defp create_response do
    %Schema{
      title: "AccountCreateResponse",
      description: "Response schema for an account",
      type: :object,
      properties: %{
        # The response when auto-login on create succeeds (token is issued):
        token_type: %Schema{type: :string},
        access_token: %Schema{type: :string},
        refresh_token: %Schema{type: :string},
        scope: %Schema{type: :string},
        created_at: %Schema{type: :integer, format: :"date-time"},
        me: %Schema{type: :string},
        expires_in: %Schema{type: :integer},
        #
        # The response when registration succeeds but auto-login fails (no token):
        identifier: %Schema{type: :string},
        message: %Schema{type: :string}
      },
      # Note: example of successful registration with failed login response:
      # example: %{
      #   "identifier" => "missing_confirmed_email",
      #   "message" => "You have been registered. Please check your email for further instructions."
      # },
      example: %{
        "token_type" => "Bearer",
        "access_token" => "i9hAVVzGld86Pl5JtLtizKoXVvtTlSCJvwaugCxvZzk",
        "refresh_token" => "i9hAVVzGld86Pl5JtLtizKoXVvtTlSCJvwaugCxvZzz",
        "created_at" => 1_585_918_714,
        "expires_in" => 600,
        "scope" => "read write follow push",
        "me" => "https://gensokyo.2hu/users/raymoo"
      }
    }
  end

  defp update_credentials_request do
    %Schema{
      title: "AccountUpdateCredentialsRequest",
      description: "POST body for creating an account",
      type: :object,
      properties: %{
        bot: %Schema{
          allOf: [BooleanLike],
          nullable: true,
          description: "Whether the account has a bot flag."
        },
        display_name: %Schema{
          type: :string,
          nullable: true,
          description: "The display name to use for the profile."
        },
        note: %Schema{type: :string, description: "The account bio."},
        avatar: %Schema{
          type: :string,
          nullable: true,
          description: "Avatar image encoded using multipart/form-data",
          format: :binary
        },
        header: %Schema{
          type: :string,
          nullable: true,
          description: "Header image encoded using multipart/form-data",
          format: :binary
        },
        locked: %Schema{
          allOf: [BooleanLike],
          nullable: true,
          description: "Whether manual approval of follow requests is required."
        },
        accepts_chat_messages: %Schema{
          allOf: [BooleanLike],
          nullable: true,
          description: "Whether the user accepts receiving chat messages."
        },
        fields_attributes: %Schema{
          nullable: true,
          oneOf: [
            %Schema{type: :array, items: attribute_field()},
            %Schema{type: :object, additionalProperties: attribute_field()}
          ]
        },
        # NOTE: `source` field is not supported
        #
        # source: %Schema{
        #   type: :object,
        #   properties: %{
        #     privacy: %Schema{type: :string},
        #     sensitive: %Schema{type: :boolean},
        #     language: %Schema{type: :string}
        #   }
        # },

        # Pleroma-specific fields
        no_rich_text: %Schema{
          allOf: [BooleanLike],
          nullable: true,
          description: "html tags are stripped from all statuses requested from the API"
        },
        hide_followers: %Schema{
          allOf: [BooleanLike],
          nullable: true,
          description: "user's followers will be hidden"
        },
        hide_follows: %Schema{
          allOf: [BooleanLike],
          nullable: true,
          description: "user's follows will be hidden"
        },
        hide_followers_count: %Schema{
          allOf: [BooleanLike],
          nullable: true,
          description: "user's follower count will be hidden"
        },
        hide_follows_count: %Schema{
          allOf: [BooleanLike],
          nullable: true,
          description: "user's follow count will be hidden"
        },
        hide_favorites: %Schema{
          allOf: [BooleanLike],
          nullable: true,
          description: "user's favorites timeline will be hidden"
        },
        show_role: %Schema{
          allOf: [BooleanLike],
          nullable: true,
          description: "user's role (e.g admin, moderator) will be exposed to anyone in the
        API"
        },
        default_scope: VisibilityScope,
        pleroma_settings_store: %Schema{
          type: :object,
          nullable: true,
          description: "Opaque user settings to be saved on the backend."
        },
        skip_thread_containment: %Schema{
          allOf: [BooleanLike],
          nullable: true,
          description: "Skip filtering out broken threads"
        },
        allow_following_move: %Schema{
          allOf: [BooleanLike],
          nullable: true,
          description: "Allows automatically follow moved following accounts"
        },
        also_known_as: %Schema{
          type: :array,
          items: %Schema{type: :string},
          nullable: true,
          description: "List of alternate ActivityPub IDs"
        },
        pleroma_background_image: %Schema{
          type: :string,
          nullable: true,
          description: "Sets the background image of the user.",
          format: :binary
        },
        discoverable: %Schema{
          allOf: [BooleanLike],
          nullable: true,
          description:
            "Discovery (listing, indexing) of this account by external services (search bots etc.) is allowed."
        },
        actor_type: ActorType
      },
      example: %{
        bot: false,
        display_name: "cofe",
        note: "foobar",
        fields_attributes: [%{name: "foo", value: "bar"}],
        no_rich_text: false,
        hide_followers: true,
        hide_follows: false,
        hide_followers_count: false,
        hide_follows_count: false,
        hide_favorites: false,
        show_role: false,
        default_scope: "private",
        pleroma_settings_store: %{"pleroma-fe" => %{"key" => "val"}},
        skip_thread_containment: false,
        allow_following_move: false,
        also_known_as: ["https://foo.bar/users/foo"],
        discoverable: false,
        actor_type: "Person"
      }
    }
  end

  def array_of_accounts do
    %Schema{
      title: "ArrayOfAccounts",
      type: :array,
      items: Account,
      example: [Account.schema().example]
    }
  end

  defp array_of_relationships do
    %Schema{
      title: "ArrayOfRelationships",
      description: "Response schema for account relationships",
      type: :array,
      items: AccountRelationship,
      example: [
        %{
          "id" => "1",
          "following" => true,
          "showing_reblogs" => true,
          "followed_by" => true,
          "blocking" => false,
          "blocked_by" => true,
          "muting" => false,
          "muting_notifications" => false,
          "note" => "",
          "requested" => false,
          "domain_blocking" => false,
          "subscribing" => false,
          "notifying" => false,
          "endorsed" => true
        },
        %{
          "id" => "2",
          "following" => true,
          "showing_reblogs" => true,
          "followed_by" => true,
          "blocking" => false,
          "blocked_by" => true,
          "muting" => true,
          "muting_notifications" => false,
          "note" => "",
          "requested" => true,
          "domain_blocking" => false,
          "subscribing" => false,
          "notifying" => false,
          "endorsed" => false
        },
        %{
          "id" => "3",
          "following" => true,
          "showing_reblogs" => true,
          "followed_by" => true,
          "blocking" => true,
          "blocked_by" => false,
          "muting" => true,
          "muting_notifications" => false,
          "note" => "",
          "requested" => false,
          "domain_blocking" => true,
          "subscribing" => true,
          "notifying" => true,
          "endorsed" => false
        }
      ]
    }
  end

  defp follow_by_uri_request do
    %Schema{
      title: "AccountFollowsRequest",
      description: "POST body for muting an account",
      type: :object,
      properties: %{
        uri: %Schema{type: :string, nullable: true, format: :uri}
      },
      required: [:uri]
    }
  end

  defp mute_request do
    %Schema{
      title: "AccountMuteRequest",
      description: "POST body for muting an account",
      type: :object,
      properties: %{
        notifications: %Schema{
          allOf: [BooleanLike],
          nullable: true,
          description: "Mute notifications in addition to statuses? Defaults to true.",
          default: true
        },
        expires_in: %Schema{
          type: :integer,
          nullable: true,
          description: "Expire the mute in `expires_in` seconds. Default 0 for infinity",
          default: 0
        }
      },
      example: %{
        "notifications" => true,
        "expires_in" => 86_400
      }
    }
  end

  defp note_request do
    %Schema{
      title: "AccountNoteRequest",
      description: "POST body for adding a note for an account",
      type: :object,
      properties: %{
        comment: %Schema{
          type: :string,
          description: "Account note body"
        }
      },
      example: %{
        "comment" => "Example note"
      }
    }
  end

  defp array_of_lists do
    %Schema{
      title: "ArrayOfLists",
      description: "Response schema for lists",
      type: :array,
      items: List,
      example: [
        %{"id" => "123", "title" => "my list"},
        %{"id" => "1337", "title" => "anotehr list"}
      ]
    }
  end

  defp array_of_statuses do
    %Schema{
      title: "ArrayOfStatuses",
      type: :array,
      items: Status
    }
  end

  defp attribute_field do
    %Schema{
      title: "AccountAttributeField",
      description: "Request schema for account custom fields",
      type: :object,
      properties: %{
        name: %Schema{type: :string},
        value: %Schema{type: :string}
      },
      required: [:name, :value],
      example: %{
        "name" => "Website",
        "value" => "https://pleroma.com"
      }
    }
  end
end
