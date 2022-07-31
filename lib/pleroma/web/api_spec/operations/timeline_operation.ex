# Pleroma: A lightweight social networking server
# Copyright © 2017-2022 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.ApiSpec.TimelineOperation do
  alias OpenApiSpex.Operation
  alias OpenApiSpex.Schema
  alias Pleroma.Web.ApiSpec.Schemas.ApiError
  alias Pleroma.Web.ApiSpec.Schemas.BooleanLike
  alias Pleroma.Web.ApiSpec.Schemas.Status
  alias Pleroma.Web.ApiSpec.Schemas.VisibilityScope

  import Pleroma.Web.ApiSpec.Helpers

  def open_api_operation(action) do
    operation = String.to_existing_atom("#{action}_operation")
    apply(__MODULE__, operation, [])
  end

  def home_operation do
    %Operation{
      tags: ["Timelines"],
      summary: "Home timeline",
      description: "View statuses from followed users",
      security: [%{"oAuth" => ["read:statuses"]}],
      parameters: [
        local_param(),
        remote_param(),
        only_media_param(),
        with_muted_param(),
        exclude_visibilities_param(),
        reply_visibility_param() | pagination_params()
      ],
      operationId: "TimelineController.home",
      responses: %{
        200 => Operation.response("Array of Status", "application/json", array_of_statuses())
      }
    }
  end

  def direct_operation do
    %Operation{
      tags: ["Timelines"],
      summary: "Direct timeline",
      description:
        "View statuses with a “direct” scope addressed to the account. Using this endpoint is discouraged, please use [conversations](#tag/Conversations) or [chats](#tag/Chats).",
      parameters: [with_muted_param() | pagination_params()],
      security: [%{"oAuth" => ["read:statuses"]}],
      operationId: "TimelineController.direct",
      responses: %{
        200 => Operation.response("Array of Status", "application/json", array_of_statuses())
      }
    }
  end

  def public_operation do
    %Operation{
      tags: ["Timelines"],
      summary: "Public timeline",
      security: [%{"oAuth" => ["read:statuses"]}],
      parameters: [
        local_param(),
        instance_param(),
        only_media_param(),
        remote_param(),
        with_muted_param(),
        exclude_visibilities_param(),
        reply_visibility_param() | pagination_params()
      ],
      operationId: "TimelineController.public",
      responses: %{
        200 => Operation.response("Array of Status", "application/json", array_of_statuses()),
        401 => Operation.response("Error", "application/json", ApiError)
      }
    }
  end

  def hashtag_operation do
    %Operation{
      tags: ["Timelines"],
      summary: "Hashtag timeline",
      description: "View public statuses containing the given hashtag",
      security: [%{"oAuth" => ["read:statuses"]}],
      parameters: [
        Operation.parameter(
          :tag,
          :path,
          %Schema{type: :string},
          "Content of a #hashtag, not including # symbol.",
          required: true
        ),
        Operation.parameter(
          :any,
          :query,
          %Schema{type: :array, items: %Schema{type: :string}},
          "Statuses that also includes any of these tags"
        ),
        Operation.parameter(
          :all,
          :query,
          %Schema{type: :array, items: %Schema{type: :string}},
          "Statuses that also includes all of these tags"
        ),
        Operation.parameter(
          :none,
          :query,
          %Schema{type: :array, items: %Schema{type: :string}},
          "Statuses that do not include these tags"
        ),
        local_param(),
        only_media_param(),
        remote_param(),
        with_muted_param(),
        exclude_visibilities_param() | pagination_params()
      ],
      operationId: "TimelineController.hashtag",
      responses: %{
        200 => Operation.response("Array of Status", "application/json", array_of_statuses()),
        401 => Operation.response("Error", "application/json", ApiError)
      }
    }
  end

  def list_operation do
    %Operation{
      tags: ["Timelines"],
      summary: "List timeline",
      description: "View statuses in the given list timeline",
      security: [%{"oAuth" => ["read:lists"]}],
      parameters: [
        Operation.parameter(
          :list_id,
          :path,
          %Schema{type: :string},
          "Local ID of the list in the database",
          required: true
        ),
        with_muted_param(),
        local_param(),
        remote_param(),
        only_media_param(),
        exclude_visibilities_param() | pagination_params()
      ],
      operationId: "TimelineController.list",
      responses: %{
        200 => Operation.response("Array of Status", "application/json", array_of_statuses())
      }
    }
  end

  defp array_of_statuses do
    %Schema{
      title: "ArrayOfStatuses",
      type: :array,
      items: Status,
      example: [Status.schema().example]
    }
  end

  defp local_param do
    Operation.parameter(
      :local,
      :query,
      %Schema{allOf: [BooleanLike], default: false},
      "Show only local statuses?"
    )
  end

  defp instance_param do
    Operation.parameter(
      :instance,
      :query,
      %Schema{type: :string},
      "Show only statuses from the given domain"
    )
  end

  defp with_muted_param do
    Operation.parameter(:with_muted, :query, BooleanLike, "Include activities by muted users")
  end

  defp exclude_visibilities_param do
    Operation.parameter(
      :exclude_visibilities,
      :query,
      %Schema{type: :array, items: VisibilityScope},
      "Exclude the statuses with the given visibilities"
    )
  end

  defp reply_visibility_param do
    Operation.parameter(
      :reply_visibility,
      :query,
      %Schema{type: :string, enum: ["following", "self"]},
      "Filter replies. Possible values: without parameter (default) shows all replies, `following` - replies directed to you or users you follow, `self` - replies directed to you."
    )
  end

  defp only_media_param do
    Operation.parameter(
      :only_media,
      :query,
      %Schema{allOf: [BooleanLike], default: false},
      "Show only statuses with media attached?"
    )
  end

  defp remote_param do
    Operation.parameter(
      :remote,
      :query,
      %Schema{allOf: [BooleanLike], default: false},
      "Show only remote statuses?"
    )
  end
end
