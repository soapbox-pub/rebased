# Pleroma: A lightweight social networking server
# Copyright © 2017-2022 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.ApiSpec.Admin.AnnouncementOperation do
  alias OpenApiSpex.Operation
  alias OpenApiSpex.Schema
  alias Pleroma.Web.ApiSpec.Schemas.Announcement
  alias Pleroma.Web.ApiSpec.Schemas.ApiError

  import Pleroma.Web.ApiSpec.Helpers

  def open_api_operation(action) do
    operation = String.to_existing_atom("#{action}_operation")
    apply(__MODULE__, operation, [])
  end

  def index_operation do
    %Operation{
      tags: ["Announcement managment"],
      summary: "Retrieve a list of announcements",
      operationId: "AdminAPI.AnnouncementController.index",
      security: [%{"oAuth" => ["admin:read"]}],
      parameters: [
        Operation.parameter(
          :limit,
          :query,
          %Schema{type: :integer, minimum: 1},
          "the maximum number of announcements to return"
        ),
        Operation.parameter(
          :offset,
          :query,
          %Schema{type: :integer, minimum: 0},
          "the offset of the first announcement to return"
        )
        | admin_api_params()
      ],
      responses: %{
        200 => Operation.response("Response", "application/json", list_of_announcements()),
        400 => Operation.response("Forbidden", "application/json", ApiError),
        403 => Operation.response("Forbidden", "application/json", ApiError)
      }
    }
  end

  def show_operation do
    %Operation{
      tags: ["Announcement managment"],
      summary: "Display one announcement",
      operationId: "AdminAPI.AnnouncementController.show",
      security: [%{"oAuth" => ["admin:read"]}],
      parameters: [
        Operation.parameter(
          :id,
          :path,
          :string,
          "announcement id"
        )
        | admin_api_params()
      ],
      responses: %{
        200 => Operation.response("Response", "application/json", Announcement),
        403 => Operation.response("Forbidden", "application/json", ApiError),
        404 => Operation.response("Not Found", "application/json", ApiError)
      }
    }
  end

  def delete_operation do
    %Operation{
      tags: ["Announcement managment"],
      summary: "Delete one announcement",
      operationId: "AdminAPI.AnnouncementController.delete",
      security: [%{"oAuth" => ["admin:write"]}],
      parameters: [
        Operation.parameter(
          :id,
          :path,
          :string,
          "announcement id"
        )
        | admin_api_params()
      ],
      responses: %{
        200 => Operation.response("Response", "application/json", %Schema{type: :object}),
        403 => Operation.response("Forbidden", "application/json", ApiError),
        404 => Operation.response("Not Found", "application/json", ApiError)
      }
    }
  end

  def create_operation do
    %Operation{
      tags: ["Announcement managment"],
      summary: "Create one announcement",
      operationId: "AdminAPI.AnnouncementController.create",
      security: [%{"oAuth" => ["admin:write"]}],
      requestBody: request_body("Parameters", create_request(), required: true),
      responses: %{
        200 => Operation.response("Response", "application/json", Announcement),
        400 => Operation.response("Bad Request", "application/json", ApiError),
        403 => Operation.response("Forbidden", "application/json", ApiError)
      }
    }
  end

  def change_operation do
    %Operation{
      tags: ["Announcement managment"],
      summary: "Change one announcement",
      operationId: "AdminAPI.AnnouncementController.change",
      security: [%{"oAuth" => ["admin:write"]}],
      parameters: [
        Operation.parameter(
          :id,
          :path,
          :string,
          "announcement id"
        )
        | admin_api_params()
      ],
      requestBody: request_body("Parameters", change_request(), required: true),
      responses: %{
        200 => Operation.response("Response", "application/json", Announcement),
        400 => Operation.response("Bad Request", "application/json", ApiError),
        403 => Operation.response("Forbidden", "application/json", ApiError),
        404 => Operation.response("Not Found", "application/json", ApiError)
      }
    }
  end

  defp create_or_change_props do
    %{
      content: %Schema{type: :string},
      starts_at: %Schema{type: :string, format: "date-time", nullable: true},
      ends_at: %Schema{type: :string, format: "date-time", nullable: true},
      all_day: %Schema{type: :boolean}
    }
  end

  def create_request do
    %Schema{
      title: "AnnouncementCreateRequest",
      type: :object,
      required: [:content],
      properties: create_or_change_props()
    }
  end

  def change_request do
    %Schema{
      title: "AnnouncementChangeRequest",
      type: :object,
      properties: create_or_change_props()
    }
  end

  def list_of_announcements do
    %Schema{
      type: :array,
      items: Announcement
    }
  end
end
