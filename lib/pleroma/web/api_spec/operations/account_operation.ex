# Pleroma: A lightweight social networking server
# Copyright © 2017-2020 Pleroma Authors <https://pleroma.social/>
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
      tags: ["accounts"],
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
      tags: ["accounts"],
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
      tags: ["accounts"],
      summary: "Update account credentials",
      description: "Update the user's display and preferences.",
      operationId: "AccountController.update_credentials",
      security: [%{"oAuth" => ["write:accounts"]}],
      requestBody: request_body("Parameters", update_creadentials_request(), required: true),
      responses: %{
        200 => Operation.response("Account", "application/json", Account),
        403 => Operation.response("Error", "application/json", ApiError)
      }
    }
  end

  def relationships_operation do
    %Operation{
      tags: ["accounts"],
      summary: "Check relationships to other accounts",
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
      tags: ["accounts"],
      summary: "Account",
      operationId: "AccountController.show",
      description: "View information about a profile.",
      parameters: [%Reference{"$ref": "#/components/parameters/accountIdOrNickname"}],
      responses: %{
        200 => Operation.response("Account", "application/json", Account),
        404 => Operation.response("Error", "application/json", ApiError)
      }
    }
  end

  def statuses_operation do
    %Operation{
      tags: ["accounts"],
      summary: "Statuses",
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
            "Include statuses from muted acccounts."
          ),
          Operation.parameter(:exclude_reblogs, :query, BooleanLike, "Exclude reblogs"),
          Operation.parameter(:exclude_replies, :query, BooleanLike, "Exclude replies"),
          Operation.parameter(
            :exclude_visibilities,
            :query,
            %Schema{type: :array, items: VisibilityScope},
            "Exclude visibilities"
          )
        ] ++ pagination_params(),
      responses: %{
        200 => Operation.response("Statuses", "application/json", array_of_statuses()),
        404 => Operation.response("Error", "application/json", ApiError)
      }
    }
  end

  def followers_operation do
    %Operation{
      tags: ["accounts"],
      summary: "Followers",
      operationId: "AccountController.followers",
      security: [%{"oAuth" => ["read:accounts"]}],
      description:
        "Accounts which follow the given account, if network is not hidden by the account owner.",
      parameters:
        [%Reference{"$ref": "#/components/parameters/accountIdOrNickname"}] ++
          pagination_params() ++ [embed_relationships_param()],
      responses: %{
        200 => Operation.response("Accounts", "application/json", array_of_accounts())
      }
    }
  end

  def following_operation do
    %Operation{
      tags: ["accounts"],
      summary: "Following",
      operationId: "AccountController.following",
      security: [%{"oAuth" => ["read:accounts"]}],
      description:
        "Accounts which the given account is following, if network is not hidden by the account owner.",
      parameters:
        [%Reference{"$ref": "#/components/parameters/accountIdOrNickname"}] ++
          pagination_params() ++ [embed_relationships_param()],
      responses: %{200 => Operation.response("Accounts", "application/json", array_of_accounts())}
    }
  end

  def lists_operation do
    %Operation{
      tags: ["accounts"],
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
      tags: ["accounts"],
      summary: "Follow",
      operationId: "AccountController.follow",
      security: [%{"oAuth" => ["follow", "write:follows"]}],
      description: "Follow the given account",
      parameters: [
        %Reference{"$ref": "#/components/parameters/accountIdOrNickname"},
        Operation.parameter(
          :reblogs,
          :query,
          BooleanLike,
          "Receive this account's reblogs in home timeline? Defaults to true."
        )
      ],
      responses: %{
        200 => Operation.response("Relationship", "application/json", AccountRelationship),
        400 => Operation.response("Error", "application/json", ApiError),
        404 => Operation.response("Error", "application/json", ApiError)
      }
    }
  end

  def unfollow_operation do
    %Operation{
      tags: ["accounts"],
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
      tags: ["accounts"],
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
        )
      ],
      responses: %{
        200 => Operation.response("Relationship", "application/json", AccountRelationship)
      }
    }
  end

  def unmute_operation do
    %Operation{
      tags: ["accounts"],
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
      tags: ["accounts"],
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
      tags: ["accounts"],
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

  def follow_by_uri_operation do
    %Operation{
      tags: ["accounts"],
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
      tags: ["accounts"],
      summary: "Muted accounts",
      operationId: "AccountController.mutes",
      description: "Accounts the user has muted.",
      security: [%{"oAuth" => ["follow", "read:mutes"]}],
      responses: %{
        200 => Operation.response("Accounts", "application/json", array_of_accounts())
      }
    }
  end

  def blocks_operation do
    %Operation{
      tags: ["accounts"],
      summary: "Blocked users",
      operationId: "AccountController.blocks",
      description: "View your blocks. See also accounts/:id/{block,unblock}",
      security: [%{"oAuth" => ["read:blocks"]}],
      responses: %{
        200 => Operation.response("Accounts", "application/json", array_of_accounts())
      }
    }
  end

  def endorsements_operation do
    %Operation{
      tags: ["accounts"],
      summary: "Endorsements",
      operationId: "AccountController.endorsements",
      description: "Not implemented",
      security: [%{"oAuth" => ["read:accounts"]}],
      responses: %{
        200 => empty_array_response()
      }
    }
  end

  def identity_proofs_operation do
    %Operation{
      tags: ["accounts"],
      summary: "Identity proofs",
      operationId: "AccountController.identity_proofs",
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
      properties: %{
        reason: %Schema{
          type: :string,
          description:
            "Text that will be reviewed by moderators if registrations require manual approval"
        },
        username: %Schema{type: :string, description: "The desired username for the account"},
        email: %Schema{
          type: :string,
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
          type: :boolean,
          description:
            "Whether the user agrees to the local rules, terms, and policies. These should be presented to the user in order to allow them to consent before setting this parameter to TRUE."
        },
        locale: %Schema{
          type: :string,
          description: "The language of the confirmation email that will be sent"
        },
        # Pleroma-specific properties:
        fullname: %Schema{type: :string, description: "Full name"},
        bio: %Schema{type: :string, description: "Bio", default: ""},
        captcha_solution: %Schema{
          type: :string,
          description: "Provider-specific captcha solution"
        },
        captcha_token: %Schema{type: :string, description: "Provider-specific captcha token"},
        captcha_answer_data: %Schema{type: :string, description: "Provider-specific captcha data"},
        token: %Schema{
          type: :string,
          description: "Invite token required when the registrations aren't public"
        }
      },
      required: [:username, :password, :agreement],
      example: %{
        "username" => "cofe",
        "email" => "cofe@example.com",
        "password" => "secret",
        "agreement" => "true",
        "bio" => "☕️"
      }
    }
  end

  defp create_response do
    %Schema{
      title: "AccountCreateResponse",
      description: "Response schema for an account",
      type: :object,
      properties: %{
        token_type: %Schema{type: :string},
        access_token: %Schema{type: :string},
        scope: %Schema{type: :array, items: %Schema{type: :string}},
        created_at: %Schema{type: :integer, format: :"date-time"}
      },
      example: %{
        "access_token" => "i9hAVVzGld86Pl5JtLtizKoXVvtTlSCJvwaugCxvZzk",
        "created_at" => 1_585_918_714,
        "scope" => ["read", "write", "follow", "push"],
        "token_type" => "Bearer"
      }
    }
  end

  defp update_creadentials_request do
    %Schema{
      title: "AccountUpdateCredentialsRequest",
      description: "POST body for creating an account",
      type: :object,
      properties: %{
        bot: %Schema{
          type: :boolean,
          description: "Whether the account has a bot flag."
        },
        display_name: %Schema{
          type: :string,
          description: "The display name to use for the profile."
        },
        note: %Schema{type: :string, description: "The account bio."},
        avatar: %Schema{
          type: :string,
          description: "Avatar image encoded using multipart/form-data",
          format: :binary
        },
        header: %Schema{
          type: :string,
          description: "Header image encoded using multipart/form-data",
          format: :binary
        },
        locked: %Schema{
          type: :boolean,
          description: "Whether manual approval of follow requests is required."
        },
        fields_attributes: %Schema{
          oneOf: [
            %Schema{type: :array, items: attribute_field()},
            %Schema{type: :object, additionalProperties: %Schema{type: attribute_field()}}
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
          type: :boolean,
          description: "html tags are stripped from all statuses requested from the API"
        },
        hide_followers: %Schema{type: :boolean, description: "user's followers will be hidden"},
        hide_follows: %Schema{type: :boolean, description: "user's follows will be hidden"},
        hide_followers_count: %Schema{
          type: :boolean,
          description: "user's follower count will be hidden"
        },
        hide_follows_count: %Schema{
          type: :boolean,
          description: "user's follow count will be hidden"
        },
        hide_favorites: %Schema{
          type: :boolean,
          description: "user's favorites timeline will be hidden"
        },
        show_role: %Schema{
          type: :boolean,
          description: "user's role (e.g admin, moderator) will be exposed to anyone in the
        API"
        },
        default_scope: VisibilityScope,
        pleroma_settings_store: %Schema{
          type: :object,
          description: "Opaque user settings to be saved on the backend."
        },
        skip_thread_containment: %Schema{
          type: :boolean,
          description: "Skip filtering out broken threads"
        },
        allow_following_move: %Schema{
          type: :boolean,
          description: "Allows automatically follow moved following accounts"
        },
        pleroma_background_image: %Schema{
          type: :string,
          description: "Sets the background image of the user.",
          format: :binary
        },
        discoverable: %Schema{
          type: :boolean,
          description:
            "Discovery of this account in search results and other services is allowed."
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
          "requested" => false,
          "domain_blocking" => false,
          "subscribing" => false,
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
          "requested" => true,
          "domain_blocking" => false,
          "subscribing" => false,
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
          "requested" => false,
          "domain_blocking" => true,
          "subscribing" => true,
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
        uri: %Schema{type: :string, format: :uri}
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
          type: :boolean,
          description: "Mute notifications in addition to statuses? Defaults to true.",
          default: true
        }
      },
      example: %{
        "notifications" => true
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
