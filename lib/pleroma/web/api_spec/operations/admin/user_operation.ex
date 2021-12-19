# Pleroma: A lightweight social networking server
# Copyright © 2017-2021 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.ApiSpec.Admin.UserOperation do
  alias OpenApiSpex.Operation
  alias OpenApiSpex.Schema
  alias Pleroma.Web.ApiSpec.Schemas.ActorType
  alias Pleroma.Web.ApiSpec.Schemas.ApiError

  import Pleroma.Web.ApiSpec.Helpers

  def open_api_operation(action) do
    operation = String.to_existing_atom("#{action}_operation")
    apply(__MODULE__, operation, [])
  end

  def index_operation do
    %Operation{
      tags: ["User administration"],
      summary: "List users",
      operationId: "AdminAPI.UserController.index",
      security: [%{"oAuth" => ["admin:read:accounts"]}],
      parameters: [
        Operation.parameter(:filters, :query, :string, "Comma separated list of filters"),
        Operation.parameter(:query, :query, :string, "Search users query"),
        Operation.parameter(:name, :query, :string, "Search by display name"),
        Operation.parameter(:email, :query, :string, "Search by email"),
        Operation.parameter(:page, :query, :integer, "Page Number"),
        Operation.parameter(:page_size, :query, :integer, "Number of users to return per page"),
        Operation.parameter(
          :actor_types,
          :query,
          %Schema{type: :array, items: ActorType},
          "Filter by actor type"
        ),
        Operation.parameter(
          :tags,
          :query,
          %Schema{type: :array, items: %Schema{type: :string}},
          "Filter by tags"
        )
        | admin_api_params()
      ],
      responses: %{
        200 =>
          Operation.response(
            "Response",
            "application/json",
            %Schema{
              type: :object,
              properties: %{
                users: %Schema{type: :array, items: user()},
                count: %Schema{type: :integer},
                page_size: %Schema{type: :integer}
              }
            }
          ),
        403 => Operation.response("Forbidden", "application/json", ApiError)
      }
    }
  end

  def create_operation do
    %Operation{
      tags: ["User administration"],
      summary: "Create a single or multiple users",
      operationId: "AdminAPI.UserController.create",
      security: [%{"oAuth" => ["admin:write:accounts"]}],
      parameters: admin_api_params(),
      requestBody:
        request_body(
          "Parameters",
          %Schema{
            description: "POST body for creating users",
            type: :object,
            properties: %{
              users: %Schema{
                type: :array,
                items: %Schema{
                  type: :object,
                  properties: %{
                    nickname: %Schema{type: :string},
                    email: %Schema{type: :string},
                    password: %Schema{type: :string}
                  }
                }
              }
            }
          }
        ),
      responses: %{
        200 =>
          Operation.response("Response", "application/json", %Schema{
            type: :array,
            items: %Schema{
              type: :object,
              properties: %{
                code: %Schema{type: :integer},
                type: %Schema{type: :string},
                data: %Schema{
                  type: :object,
                  properties: %{
                    email: %Schema{type: :string, format: :email},
                    nickname: %Schema{type: :string}
                  }
                }
              }
            }
          }),
        403 => Operation.response("Forbidden", "application/json", ApiError),
        409 =>
          Operation.response("Conflict", "application/json", %Schema{
            type: :array,
            items: %Schema{
              type: :object,
              properties: %{
                code: %Schema{type: :integer},
                error: %Schema{type: :string},
                type: %Schema{type: :string},
                data: %Schema{
                  type: :object,
                  properties: %{
                    email: %Schema{type: :string, format: :email},
                    nickname: %Schema{type: :string}
                  }
                }
              }
            }
          })
      }
    }
  end

  def show_operation do
    %Operation{
      tags: ["User administration"],
      summary: "Show user",
      operationId: "AdminAPI.UserController.show",
      security: [%{"oAuth" => ["admin:read:accounts"]}],
      parameters: [
        Operation.parameter(
          :nickname,
          :path,
          :string,
          "User nickname or ID"
        )
        | admin_api_params()
      ],
      responses: %{
        200 => Operation.response("Response", "application/json", user()),
        403 => Operation.response("Forbidden", "application/json", ApiError),
        404 => Operation.response("Not Found", "application/json", ApiError)
      }
    }
  end

  def follow_operation do
    %Operation{
      tags: ["User administration"],
      summary: "Follow",
      operationId: "AdminAPI.UserController.follow",
      security: [%{"oAuth" => ["admin:write:follows"]}],
      parameters: admin_api_params(),
      requestBody:
        request_body(
          "Parameters",
          %Schema{
            type: :object,
            properties: %{
              follower: %Schema{type: :string, description: "Follower nickname"},
              followed: %Schema{type: :string, description: "Followed nickname"}
            }
          }
        ),
      responses: %{
        200 => Operation.response("Response", "application/json", %Schema{type: :string}),
        403 => Operation.response("Forbidden", "application/json", ApiError)
      }
    }
  end

  def unfollow_operation do
    %Operation{
      tags: ["User administration"],
      summary: "Unfollow",
      operationId: "AdminAPI.UserController.unfollow",
      security: [%{"oAuth" => ["admin:write:follows"]}],
      parameters: admin_api_params(),
      requestBody:
        request_body(
          "Parameters",
          %Schema{
            type: :object,
            properties: %{
              follower: %Schema{type: :string, description: "Follower nickname"},
              followed: %Schema{type: :string, description: "Followed nickname"}
            }
          }
        ),
      responses: %{
        200 => Operation.response("Response", "application/json", %Schema{type: :string}),
        403 => Operation.response("Forbidden", "application/json", ApiError)
      }
    }
  end

  def approve_operation do
    %Operation{
      tags: ["User administration"],
      summary: "Approve multiple users",
      operationId: "AdminAPI.UserController.approve",
      security: [%{"oAuth" => ["admin:write:accounts"]}],
      parameters: admin_api_params(),
      requestBody:
        request_body(
          "Parameters",
          %Schema{
            description: "POST body for approving multiple users",
            type: :object,
            properties: %{
              nicknames: %Schema{
                type: :array,
                items: %Schema{type: :string}
              }
            }
          }
        ),
      responses: %{
        200 =>
          Operation.response("Response", "application/json", %Schema{
            type: :object,
            properties: %{user: %Schema{type: :array, items: user()}}
          }),
        403 => Operation.response("Forbidden", "application/json", ApiError)
      }
    }
  end

  def suggest_operation do
    %Operation{
      tags: ["User administration"],
      summary: "Suggest multiple users",
      operationId: "AdminAPI.UserController.suggest",
      security: [%{"oAuth" => ["admin:write:accounts"]}],
      parameters: admin_api_params(),
      requestBody:
        request_body(
          "Parameters",
          %Schema{
            description: "POST body for adding multiple suggested users",
            type: :object,
            properties: %{
              nicknames: %Schema{
                type: :array,
                items: %Schema{type: :string}
              }
            }
          }
        ),
      responses: %{
        200 =>
          Operation.response("Response", "application/json", %Schema{
            type: :object,
            properties: %{user: %Schema{type: :array, items: user()}}
          }),
        403 => Operation.response("Forbidden", "application/json", ApiError)
      }
    }
  end

  def unsuggest_operation do
    %Operation{
      tags: ["User administration"],
      summary: "Unsuggest multiple users",
      operationId: "AdminAPI.UserController.unsuggest",
      security: [%{"oAuth" => ["admin:write:accounts"]}],
      parameters: admin_api_params(),
      requestBody:
        request_body(
          "Parameters",
          %Schema{
            description: "POST body for removing multiple suggested users",
            type: :object,
            properties: %{
              nicknames: %Schema{
                type: :array,
                items: %Schema{type: :string}
              }
            }
          }
        ),
      responses: %{
        200 =>
          Operation.response("Response", "application/json", %Schema{
            type: :object,
            properties: %{user: %Schema{type: :array, items: user()}}
          }),
        403 => Operation.response("Forbidden", "application/json", ApiError)
      }
    }
  end

  def toggle_activation_operation do
    %Operation{
      tags: ["User administration"],
      summary: "Toggle user activation",
      operationId: "AdminAPI.UserController.toggle_activation",
      security: [%{"oAuth" => ["admin:write:accounts"]}],
      parameters: [
        Operation.parameter(:nickname, :path, :string, "User nickname")
        | admin_api_params()
      ],
      responses: %{
        200 => Operation.response("Response", "application/json", user()),
        403 => Operation.response("Forbidden", "application/json", ApiError)
      }
    }
  end

  def activate_operation do
    %Operation{
      tags: ["User administration"],
      summary: "Activate multiple users",
      operationId: "AdminAPI.UserController.activate",
      security: [%{"oAuth" => ["admin:write:accounts"]}],
      parameters: admin_api_params(),
      requestBody:
        request_body(
          "Parameters",
          %Schema{
            description: "POST body for deleting multiple users",
            type: :object,
            properties: %{
              nicknames: %Schema{
                type: :array,
                items: %Schema{type: :string}
              }
            }
          }
        ),
      responses: %{
        200 =>
          Operation.response("Response", "application/json", %Schema{
            type: :object,
            properties: %{user: %Schema{type: :array, items: user()}}
          }),
        403 => Operation.response("Forbidden", "application/json", ApiError)
      }
    }
  end

  def deactivate_operation do
    %Operation{
      tags: ["User administration"],
      summary: "Deactivates multiple users",
      operationId: "AdminAPI.UserController.deactivate",
      security: [%{"oAuth" => ["admin:write:accounts"]}],
      parameters: admin_api_params(),
      requestBody:
        request_body(
          "Parameters",
          %Schema{
            description: "POST body for deleting multiple users",
            type: :object,
            properties: %{
              nicknames: %Schema{
                type: :array,
                items: %Schema{type: :string}
              }
            }
          }
        ),
      responses: %{
        200 =>
          Operation.response("Response", "application/json", %Schema{
            type: :object,
            properties: %{user: %Schema{type: :array, items: user()}}
          }),
        403 => Operation.response("Forbidden", "application/json", ApiError)
      }
    }
  end

  def delete_operation do
    %Operation{
      tags: ["User administration"],
      summary: "Removes a single or multiple users",
      operationId: "AdminAPI.UserController.delete",
      security: [%{"oAuth" => ["admin:write:accounts"]}],
      parameters: [
        Operation.parameter(
          :nickname,
          :query,
          :string,
          "User nickname"
        )
        | admin_api_params()
      ],
      requestBody:
        request_body(
          "Parameters",
          %Schema{
            description: "POST body for deleting multiple users",
            type: :object,
            properties: %{
              nicknames: %Schema{
                type: :array,
                items: %Schema{type: :string}
              }
            }
          }
        ),
      responses: %{
        200 =>
          Operation.response("Response", "application/json", %Schema{
            description: "Array of nicknames",
            type: :array,
            items: %Schema{type: :string}
          }),
        403 => Operation.response("Forbidden", "application/json", ApiError)
      }
    }
  end

  defp user do
    %Schema{
      type: :object,
      properties: %{
        id: %Schema{type: :string},
        email: %Schema{type: :string, format: :email},
        avatar: %Schema{type: :string, format: :uri},
        nickname: %Schema{type: :string},
        display_name: %Schema{type: :string},
        is_active: %Schema{type: :boolean},
        local: %Schema{type: :boolean},
        roles: %Schema{
          type: :object,
          properties: %{
            admin: %Schema{type: :boolean},
            moderator: %Schema{type: :boolean}
          }
        },
        tags: %Schema{type: :array, items: %Schema{type: :string}},
        is_confirmed: %Schema{type: :boolean},
        is_approved: %Schema{type: :boolean},
        url: %Schema{type: :string, format: :uri},
        registration_reason: %Schema{type: :string, nullable: true},
        actor_type: %Schema{type: :string}
      }
    }
  end
end
