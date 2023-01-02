# Pleroma: A lightweight social networking server
# Copyright © 2017-2022 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Tests.ApiSpecHelpers do
  @moduledoc """
  OpenAPI spec test helpers
  """

  import ExUnit.Assertions

  alias OpenApiSpex.Cast.Error
  alias OpenApiSpex.Reference
  alias OpenApiSpex.Schema

  def assert_schema(value, schema) do
    api_spec = Pleroma.Web.ApiSpec.spec()

    case OpenApiSpex.cast_value(value, schema, api_spec) do
      {:ok, data} ->
        data

      {:error, errors} ->
        errors =
          Enum.map(errors, fn error ->
            message = Error.message(error)
            path = Error.path_to_string(error)
            "#{message} at #{path}"
          end)

        flunk(
          "Value does not conform to schema #{schema.title}: #{Enum.join(errors, "\n")}\n#{inspect(value)}"
        )
    end
  end

  def resolve_schema(%Schema{} = schema), do: schema

  def resolve_schema(%Reference{} = ref) do
    schemas = Pleroma.Web.ApiSpec.spec().components.schemas
    Reference.resolve_schema(ref, schemas)
  end

  def api_operations do
    paths = Pleroma.Web.ApiSpec.spec().paths

    Enum.flat_map(paths, fn {_, path_item} ->
      path_item
      |> Map.take([:delete, :get, :head, :options, :patch, :post, :put, :trace])
      |> Map.values()
      |> Enum.reject(&is_nil/1)
    end)
    |> Enum.uniq()
  end
end
