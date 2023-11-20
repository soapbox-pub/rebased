# Pleroma: A lightweight social networking server
# Copyright © 2017-2022 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.ApiSpec.PleromaScrobbleOperation do
  alias OpenApiSpex.Operation
  alias OpenApiSpex.Reference
  alias OpenApiSpex.Schema
  alias Pleroma.Web.ApiSpec.Schemas.Account
  alias Pleroma.Web.ApiSpec.Schemas.VisibilityScope

  import Pleroma.Web.ApiSpec.Helpers

  def open_api_operation(action) do
    operation = String.to_existing_atom("#{action}_operation")
    apply(__MODULE__, operation, [])
  end

  def create_operation do
    %Operation{
      tags: ["Scrobbles"],
      summary: "Creates a new Listen activity for an account",
      security: [%{"oAuth" => ["write"]}],
      operationId: "PleromaAPI.ScrobbleController.create",
      requestBody: request_body("Parameters", create_request(), requried: true),
      responses: %{
        200 => Operation.response("Scrobble", "application/json", scrobble())
      }
    }
  end

  def index_operation do
    %Operation{
      tags: ["Scrobbles"],
      summary: "Requests a list of current and recent Listen activities for an account",
      operationId: "PleromaAPI.ScrobbleController.index",
      parameters: [
        %Reference{"$ref": "#/components/parameters/accountIdOrNickname"} | pagination_params()
      ],
      security: [%{"oAuth" => ["read"]}],
      responses: %{
        200 =>
          Operation.response("Array of Scrobble", "application/json", %Schema{
            type: :array,
            items: scrobble()
          })
      }
    }
  end

  defp create_request do
    %Schema{
      type: :object,
      required: [:title],
      properties: %{
        title: %Schema{type: :string, description: "The title of the media playing"},
        album: %Schema{type: :string, description: "The album of the media playing"},
        artist: %Schema{type: :string, description: "The artist of the media playing"},
        length: %Schema{type: :integer, description: "The length of the media playing"},
        visibility: %Schema{
          allOf: [VisibilityScope],
          default: "public",
          description: "Scrobble visibility"
        }
      },
      example: %{
        "title" => "Some Title",
        "artist" => "Some Artist",
        "album" => "Some Album",
        "length" => 180_000
      }
    }
  end

  defp scrobble do
    %Schema{
      type: :object,
      properties: %{
        id: %Schema{type: :string},
        account: Account,
        title: %Schema{type: :string, description: "The title of the media playing"},
        album: %Schema{type: :string, description: "The album of the media playing"},
        artist: %Schema{type: :string, description: "The artist of the media playing"},
        length: %Schema{
          type: :integer,
          description: "The length of the media playing",
          nullable: true
        },
        created_at: %Schema{type: :string, format: :"date-time"}
      },
      example: %{
        "id" => "1234",
        "account" => Account.schema().example,
        "title" => "Some Title",
        "artist" => "Some Artist",
        "album" => "Some Album",
        "length" => 180_000,
        "created_at" => "2019-09-28T12:40:45.000Z"
      }
    }
  end
end
