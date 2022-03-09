# Pleroma: A lightweight social networking server
# Copyright © 2017-2022 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.ApiSpec.Helpers do
  alias OpenApiSpex.Operation
  alias OpenApiSpex.Schema
  alias Pleroma.Web.ApiSpec.Schemas.BooleanLike

  def request_body(description, schema_ref, opts \\ []) do
    media_types = ["application/json", "multipart/form-data", "application/x-www-form-urlencoded"]

    content =
      media_types
      |> Enum.map(fn type ->
        {type,
         %OpenApiSpex.MediaType{
           schema: schema_ref,
           example: opts[:example],
           examples: opts[:examples]
         }}
      end)
      |> Enum.into(%{})

    %OpenApiSpex.RequestBody{
      description: description,
      content: content,
      required: opts[:required] || false
    }
  end

  def admin_api_params do
    [Operation.parameter(:admin_token, :query, :string, "Allows authorization via admin token.")]
  end

  def pagination_params do
    [
      Operation.parameter(:max_id, :query, :string, "Return items older than this ID"),
      Operation.parameter(:min_id, :query, :string, "Return the oldest items newer than this ID"),
      Operation.parameter(
        :since_id,
        :query,
        :string,
        "Return the newest items newer than this ID"
      ),
      Operation.parameter(
        :offset,
        :query,
        %Schema{type: :integer, default: 0},
        "Return items past this number of items"
      ),
      Operation.parameter(
        :limit,
        :query,
        %Schema{type: :integer, default: 20},
        "Maximum number of items to return. Will be ignored if it's more than 40"
      )
    ]
  end

  def with_relationships_param do
    Operation.parameter(
      :with_relationships,
      :query,
      BooleanLike,
      "Embed relationships into accounts. **If this parameter is not set account's `pleroma.relationship` is going to be `null`.**"
    )
  end

  def empty_object_response do
    Operation.response("Empty object", "application/json", %Schema{type: :object, example: %{}})
  end

  def empty_array_response do
    Operation.response("Empty array", "application/json", %Schema{
      type: :array,
      items: %Schema{type: :object, example: %{}},
      example: []
    })
  end

  def no_content_response do
    Operation.response("No Content", "application/json", %Schema{type: :string, example: ""})
  end
end
