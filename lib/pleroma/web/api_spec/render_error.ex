# Pleroma: A lightweight social networking server
# Copyright © 2017-2021 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.ApiSpec.RenderError do
  @behaviour Plug

  import Plug.Conn, only: [put_status: 2]
  import Phoenix.Controller, only: [json: 2]
  import Pleroma.Web.Gettext

  @impl Plug
  def init(opts), do: opts

  @impl Plug

  def call(conn, errors) do
    errors =
      Enum.map(errors, fn
        %{name: nil, reason: :invalid_enum} = err ->
          %OpenApiSpex.Cast.Error{err | name: err.value}

        %{name: nil} = err ->
          %OpenApiSpex.Cast.Error{err | name: List.last(err.path)}

        err ->
          err
      end)

    conn
    |> put_status(:bad_request)
    |> json(%{
      error: errors |> Enum.map(&message/1) |> Enum.join(" "),
      errors: errors |> Enum.map(&render_error/1)
    })
  end

  defp render_error(error) do
    pointer = OpenApiSpex.path_to_string(error)

    %{
      title: "Invalid value",
      source: %{
        pointer: pointer
      },
      message: OpenApiSpex.Cast.Error.message(error)
    }
  end

  defp message(%{reason: :invalid_schema_type, type: type, name: name}) do
    gettext("%{name} - Invalid schema.type. Got: %{type}.",
      name: name,
      type: inspect(type)
    )
  end

  defp message(%{reason: :null_value, name: name} = error) do
    case error.type do
      nil ->
        gettext("%{name} - null value.", name: name)

      type ->
        gettext("%{name} - null value where %{type} expected.",
          name: name,
          type: type
        )
    end
  end

  defp message(%{reason: :all_of, meta: %{invalid_schema: invalid_schema}}) do
    gettext(
      "Failed to cast value as %{invalid_schema}. Value must be castable using `allOf` schemas listed.",
      invalid_schema: invalid_schema
    )
  end

  defp message(%{reason: :any_of, meta: %{failed_schemas: failed_schemas}}) do
    gettext("Failed to cast value using any of: %{failed_schemas}.",
      failed_schemas: failed_schemas
    )
  end

  defp message(%{reason: :one_of, meta: %{failed_schemas: failed_schemas}}) do
    gettext("Failed to cast value to one of: %{failed_schemas}.", failed_schemas: failed_schemas)
  end

  defp message(%{reason: :min_length, length: length, name: name}) do
    gettext("%{name} - String length is smaller than minLength: %{length}.",
      name: name,
      length: length
    )
  end

  defp message(%{reason: :max_length, length: length, name: name}) do
    gettext("%{name} - String length is larger than maxLength: %{length}.",
      name: name,
      length: length
    )
  end

  defp message(%{reason: :unique_items, name: name}) do
    gettext("%{name} - Array items must be unique.", name: name)
  end

  defp message(%{reason: :min_items, length: min, value: array, name: name}) do
    gettext("%{name} - Array length %{length} is smaller than minItems: %{min}.",
      name: name,
      length: length(array),
      min: min
    )
  end

  defp message(%{reason: :max_items, length: max, value: array, name: name}) do
    gettext("%{name} - Array length %{length} is larger than maxItems: %{}.",
      name: name,
      length: length(array),
      max: max
    )
  end

  defp message(%{reason: :multiple_of, length: multiple, value: count, name: name}) do
    gettext("%{name} - %{count} is not a multiple of %{multiple}.",
      name: name,
      count: count,
      multiple: multiple
    )
  end

  defp message(%{reason: :exclusive_max, length: max, value: value, name: name})
       when value >= max do
    gettext("%{name} - %{value} is larger than exclusive maximum %{max}.",
      name: name,
      value: value,
      max: max
    )
  end

  defp message(%{reason: :maximum, length: max, value: value, name: name})
       when value > max do
    gettext("%{name} - %{value} is larger than inclusive maximum %{max}.",
      name: name,
      value: value,
      max: max
    )
  end

  defp message(%{reason: :exclusive_multiple, length: min, value: value, name: name})
       when value <= min do
    gettext("%{name} - %{value} is smaller than exclusive minimum %{min}.",
      name: name,
      value: value,
      min: min
    )
  end

  defp message(%{reason: :minimum, length: min, value: value, name: name})
       when value < min do
    gettext("%{name} - %{value} is smaller than inclusive minimum %{min}.",
      name: name,
      value: value,
      min: min
    )
  end

  defp message(%{reason: :invalid_type, type: type, value: value, name: name}) do
    gettext("%{name} - Invalid %{type}. Got: %{value}.",
      name: name,
      value: OpenApiSpex.TermType.type(value),
      type: type
    )
  end

  defp message(%{reason: :invalid_format, format: format, name: name}) do
    gettext("%{name} - Invalid format. Expected %{format}.", name: name, format: inspect(format))
  end

  defp message(%{reason: :invalid_enum, name: name}) do
    gettext("%{name} - Invalid value for enum.", name: name)
  end

  defp message(%{reason: :polymorphic_failed, type: polymorphic_type}) do
    gettext("Failed to cast to any schema in %{polymorphic_type}",
      polymorphic_type: polymorphic_type
    )
  end

  defp message(%{reason: :unexpected_field, name: name}) do
    gettext("Unexpected field: %{name}.", name: safe_string(name))
  end

  defp message(%{reason: :no_value_for_discriminator, name: field}) do
    gettext("Value used as discriminator for `%{field}` matches no schemas.", name: field)
  end

  defp message(%{reason: :invalid_discriminator_value, name: field}) do
    gettext("No value provided for required discriminator `%{field}`.", name: field)
  end

  defp message(%{reason: :unknown_schema, name: name}) do
    gettext("Unknown schema: %{name}.", name: name)
  end

  defp message(%{reason: :missing_field, name: name}) do
    gettext("Missing field: %{name}.", name: name)
  end

  defp message(%{reason: :missing_header, name: name}) do
    gettext("Missing header: %{name}.", name: name)
  end

  defp message(%{reason: :invalid_header, name: name}) do
    gettext("Invalid value for header: %{name}.", name: name)
  end

  defp message(%{reason: :max_properties, meta: meta}) do
    gettext(
      "Object property count %{property_count} is greater than maxProperties: %{max_properties}.",
      property_count: meta.property_count,
      max_properties: meta.max_properties
    )
  end

  defp message(%{reason: :min_properties, meta: meta}) do
    gettext(
      "Object property count %{property_count} is less than minProperties: %{min_properties}",
      property_count: meta.property_count,
      min_properties: meta.min_properties
    )
  end

  defp safe_string(string) do
    to_string(string) |> String.slice(0..39)
  end
end
