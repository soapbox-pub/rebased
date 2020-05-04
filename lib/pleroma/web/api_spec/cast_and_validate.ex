# Pleroma: A lightweight social networking server
# Copyright © 2019-2020 Moxley Stratton, Mike Buhot <https://github.com/open-api-spex/open_api_spex>, MPL-2.0
# Copyright © 2020 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.ApiSpec.CastAndValidate do
  @moduledoc """
  This plug is based on [`OpenApiSpex.Plug.CastAndValidate`]
  (https://github.com/open-api-spex/open_api_spex/blob/master/lib/open_api_spex/plug/cast_and_validate.ex).
  The main difference is ignoring unexpected query params
  instead of throwing an error. Also, the default rendering
  error module is `Pleroma.Web.ApiSpec.RenderError`.
  """

  @behaviour Plug

  alias Plug.Conn

  @impl Plug
  def init(opts) do
    opts
    |> Map.new()
    |> Map.put_new(:render_error, Pleroma.Web.ApiSpec.RenderError)
  end

  @impl Plug
  def call(%{private: %{open_api_spex: private_data}} = conn, %{
        operation_id: operation_id,
        render_error: render_error
      }) do
    spec = private_data.spec
    operation = private_data.operation_lookup[operation_id]

    content_type =
      case Conn.get_req_header(conn, "content-type") do
        [header_value | _] ->
          header_value
          |> String.split(";")
          |> List.first()

        _ ->
          nil
      end

    private_data = Map.put(private_data, :operation_id, operation_id)
    conn = Conn.put_private(conn, :open_api_spex, private_data)

    case cast_and_validate(spec, operation, conn, content_type) do
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
            open_api_spex: private_data
          }
        } = conn,
        opts
      ) do
    operation =
      case private_data.operation_lookup[{controller, action}] do
        nil ->
          operation_id = controller.open_api_operation(action).operationId
          operation = private_data.operation_lookup[operation_id]

          operation_lookup =
            private_data.operation_lookup
            |> Map.put({controller, action}, operation)

          OpenApiSpex.Plug.Cache.adapter().put(
            private_data.spec_module,
            {private_data.spec, operation_lookup}
          )

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

  defp cast_and_validate(spec, operation, conn, content_type) do
    case OpenApiSpex.cast_and_validate(spec, operation, conn, content_type) do
      {:ok, conn} ->
        {:ok, conn}

      # Remove unexpected query params and cast/validate again
      {:error, errors} ->
        query_params =
          Enum.reduce(errors, conn.query_params, fn
            %{reason: :unexpected_field, name: name, path: [name]}, params ->
              Map.delete(params, name)

            _, params ->
              params
          end)

        conn = %Conn{conn | query_params: query_params}
        OpenApiSpex.cast_and_validate(spec, operation, conn, content_type)
    end
  end
end
