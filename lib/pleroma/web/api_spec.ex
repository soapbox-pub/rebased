# Pleroma: A lightweight social networking server
# Copyright © 2017-2022 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.ApiSpec do
  alias OpenApiSpex.OpenApi
  alias OpenApiSpex.Operation
  alias Pleroma.Web.Endpoint
  alias Pleroma.Web.Router

  @behaviour OpenApi

  @impl OpenApi
  def spec(opts \\ []) do
    %OpenApi{
      servers:
        if opts[:server_specific] do
          [
            # Populate the Server info from a phoenix endpoint
            OpenApiSpex.Server.from_endpoint(Endpoint)
          ]
        else
          []
        end,
      info: %OpenApiSpex.Info{
        title: "Pleroma API",
        description: """
        This is documentation for client Pleroma API. Most of the endpoints and entities come
        from Mastodon API and have custom extensions on top.

        While this document aims to be a complete guide to the client API Pleroma exposes,
        the details are still being worked out. Some endpoints may have incomplete or poorly worded documentation.
        You might want to check the following resources if something is not clear:
        - [Legacy Pleroma-specific endpoint documentation](https://docs-develop.pleroma.social/backend/development/API/pleroma_api/)
        - [Mastodon API documentation](https://docs.joinmastodon.org/client/intro/)
        - [Differences in Mastodon API responses from vanilla Mastodon](https://docs-develop.pleroma.social/backend/development/API/differences_in_mastoapi_responses/)

        Please report such occurences on our [issue tracker](https://git.pleroma.social/pleroma/pleroma/-/issues). Feel free to submit API questions or proposals there too!
        """,
        # Strip environment from the version
        version: Application.spec(:pleroma, :vsn) |> to_string() |> String.replace(~r/\+.*$/, ""),
        extensions: %{
          # Logo path should be picked so that the path exists both on Pleroma instances and on api.pleroma.social
          "x-logo": %{"url" => "/static/logo.svg", "altText" => "Pleroma logo"}
        }
      },
      # populate the paths from a phoenix router
      paths: OpenApiSpex.Paths.from_router(Router),
      components: %OpenApiSpex.Components{
        parameters: %{
          "accountIdOrNickname" =>
            Operation.parameter(:id, :path, :string, "Account ID or nickname",
              example: "123",
              required: true
            )
        },
        securitySchemes: %{
          "oAuth" => %OpenApiSpex.SecurityScheme{
            type: "oauth2",
            flows: %OpenApiSpex.OAuthFlows{
              password: %OpenApiSpex.OAuthFlow{
                authorizationUrl: "/oauth/authorize",
                tokenUrl: "/oauth/token",
                scopes: %{
                  # TODO: Document granular scopes
                  "read" => "Read everything",
                  "write" => "Write everything",
                  "follow" => "Manage relationships",
                  "push" => "Web Push API subscriptions"
                }
              }
            }
          }
        }
      },
      extensions: %{
        # Redoc-specific extension, every time a new tag is added it should be reflected here,
        # otherwise it won't be shown.
        "x-tagGroups": [
          %{
            "name" => "Accounts",
            "tags" => ["Account actions", "Retrieve account information", "Scrobbles"]
          },
          %{
            "name" => "Administration",
            "tags" => [
              "Chat administration",
              "Emoji pack administration",
              "Frontend managment",
              "Instance configuration",
              "Instance documents",
              "Invites",
              "MediaProxy cache",
              "OAuth application managment",
              "Relays",
              "Report managment",
              "Status administration",
              "User administration"
            ]
          },
          %{"name" => "Applications", "tags" => ["Applications", "Push subscriptions"]},
          %{
            "name" => "Current account",
            "tags" => [
              "Account credentials",
              "Backups",
              "Blocks and mutes",
              "Data import",
              "Domain blocks",
              "Follow requests",
              "Mascot",
              "Markers",
              "Notifications"
            ]
          },
          %{"name" => "Instance", "tags" => ["Custom emojis"]},
          %{"name" => "Messaging", "tags" => ["Chats", "Conversations"]},
          %{
            "name" => "Statuses",
            "tags" => [
              "Emoji reactions",
              "Lists",
              "Polls",
              "Timelines",
              "Retrieve status information",
              "Scheduled statuses",
              "Search",
              "Status actions"
            ]
          },
          %{"name" => "Miscellaneous", "tags" => ["Emoji packs", "Reports", "Suggestions"]}
        ]
      }
    }
    # discover request/response schemas from path specs
    |> OpenApiSpex.resolve_schema_modules()
  end
end
