# Pleroma: A lightweight social networking server
# Copyright © 2019-2020 Moxley Stratton, Mike Buhot <https://github.com/open-api-spex/open_api_spex>, MPL-2.0
# Copyright © 2017-2021 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.ApiSpec.CastAndValidate do
  @moduledoc """
  This plug is based on [`OpenApiSpex.Plug.CastAndValidate`]
  (https://github.com/open-api-spex/open_api_spex/blob/master/lib/open_api_spex/plug/cast_and_validate.ex).
  The main difference is ignoring unexpected query params instead of throwing
  an error and a config option (`[Pleroma.Web.ApiSpec.CastAndValidate, :strict]`)
  to disable this behavior. Also, the default rendering error module
  is `Pleroma.Web.ApiSpec.RenderError`.
  """

  @behaviour Plug

  alias OpenApiSpex.Plug.PutApiSpec
  alias Plug.Conn

  @impl Plug
  def init(opts) do
    opts
    |> Map.new()
    |> Map.put_new(:render_error, Pleroma.Web.ApiSpec.RenderError)
  end

  @impl Plug

  def call(conn, %{operation_id: operation_id, render_error: render_error}) do
    {spec, operation_lookup} = PutApiSpec.get_spec_and_operation_lookup(conn)
    operation = operation_lookup[operation_id]

    content_type =
      case Conn.get_req_header(conn, "content-type") do
        [header_value | _] ->
          header_value
          |> String.split(";")
          |> List.first()

        _ ->
          "application/json"
      end

    conn = Conn.put_private(conn, :operation_id, operation_id)

    case cast_and_validate(spec, operation, conn, content_type, strict?()) do
      {:ok, conn} ->
        conn

      {:error, reason} ->
        opts = render_error.init(reason)

        conn
        |> render_error.call(opts)
        |> Plug.Conn.halt()
    end
  end

  def call(
        %{
          private: %{
            phoenix_controller: controller,
            phoenix_action: action,
            open_api_spex: %{spec_module: spec_module}
          }
        } = conn,
        opts
      ) do
    {spec, operation_lookup} = PutApiSpec.get_spec_and_operation_lookup(conn)

    operation =
      case operation_lookup[{controller, action}] do
        nil ->
          operation_id = controller.open_api_operation(action).operationId
          operation = operation_lookup[operation_id]

          operation_lookup = Map.put(operation_lookup, {controller, action}, operation)

          OpenApiSpex.Plug.Cache.adapter().put(spec_module, {spec, operation_lookup})

          operation

        operation ->
          operation
      end

    if operation.operationId do
      call(conn, Map.put(opts, :operation_id, operation.operationId))
    else
      raise "operationId was not found in action API spec"
    end
  end

  def call(conn, opts), do: OpenApiSpex.Plug.CastAndValidate.call(conn, opts)

  defp cast_and_validate(spec, operation, conn, content_type, true = _strict) do
    OpenApiSpex.cast_and_validate(spec, operation, conn, content_type)
  end

  defp cast_and_validate(spec, operation, conn, content_type, false = _strict) do
    case OpenApiSpex.cast_and_validate(spec, operation, conn, content_type) do
      {:ok, conn} ->
        {:ok, conn}

      # Remove unexpected query params and cast/validate again
      {:error, errors} ->
        query_params =
          Enum.reduce(errors, conn.query_params, fn
            %{reason: :unexpected_field, name: name, path: [name]}, params ->
              Map.delete(params, name)

            # Filter out empty params
            %{reason: :invalid_type, path: [name_atom], value: ""}, params ->
              Map.delete(params, to_string(name_atom))

            %{reason: :invalid_enum, name: nil, path: path, value: value}, params ->
              path = path |> Enum.reverse() |> tl() |> Enum.reverse() |> list_items_to_string()
              update_in(params, path, &List.delete(&1, value))

            _, params ->
              params
          end)

        conn = %Conn{conn | query_params: query_params}
        OpenApiSpex.cast_and_validate(spec, operation, conn, content_type)
    end
  end

  defp list_items_to_string(list) do
    Enum.map(list, fn
      i when is_atom(i) -> to_string(i)
      i -> i
    end)
  end

  defp strict?, do: Pleroma.Config.get([__MODULE__, :strict], false)
end
