# Pleroma: A lightweight social networking server
# Copyright © 2017-2022 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.ApiSpec.AnnouncementOperation do
  alias OpenApiSpex.Operation
  alias OpenApiSpex.Schema
  alias Pleroma.Web.ApiSpec.Schemas.Announcement
  alias Pleroma.Web.ApiSpec.Schemas.ApiError

  def open_api_operation(action) do
    operation = String.to_existing_atom("#{action}_operation")
    apply(__MODULE__, operation, [])
  end

  def index_operation do
    %Operation{
      tags: ["Announcement"],
      summary: "Retrieve a list of announcements",
      operationId: "MastodonAPI.AnnouncementController.index",
      security: [%{"oAuth" => []}],
      responses: %{
        200 => Operation.response("Response", "application/json", list_of_announcements()),
        403 => Operation.response("Forbidden", "application/json", ApiError)
      }
    }
  end

  def mark_read_operation do
    %Operation{
      tags: ["Announcement"],
      summary: "Mark one announcement as read",
      operationId: "MastodonAPI.AnnouncementController.mark_read",
      security: [%{"oAuth" => ["write:accounts"]}],
      parameters: [
        Operation.parameter(
          :id,
          :path,
          :string,
          "announcement id"
        )
      ],
      responses: %{
        200 => Operation.response("Response", "application/json", %Schema{type: :object}),
        403 => Operation.response("Forbidden", "application/json", ApiError),
        404 => Operation.response("Not Found", "application/json", ApiError)
      }
    }
  end

  def list_of_announcements do
    %Schema{
      type: :array,
      items: Announcement
    }
  end
end
