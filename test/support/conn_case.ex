# Pleroma: A lightweight social networking server
# Copyright © 2017-2022 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.ConnCase do
  @moduledoc """
  This module defines the test case to be used by
  tests that require setting up a connection.

  Such tests rely on `Phoenix.ConnTest` and also
  import other functionality to make it easier
  to build common datastructures and query the data layer.

  Finally, if the test case interacts with the database,
  it cannot be async. For this reason, every test runs
  inside a transaction which is reset at the beginning
  of the test unless the test case is marked as async.
  """

  use ExUnit.CaseTemplate

  alias Pleroma.DataCase

  using do
    quote do
      # Import conveniences for testing with connections
      import Plug.Conn
      import Phoenix.ConnTest
      use Pleroma.Tests.Helpers
      import Pleroma.Web.Router.Helpers

      alias Pleroma.Config

      # The default endpoint for testing
      @endpoint Pleroma.Web.Endpoint

      # Sets up OAuth access with specified scopes
      defp oauth_access(scopes, opts \\ []) do
        user =
          Keyword.get_lazy(opts, :user, fn ->
            Pleroma.Factory.insert(:user)
          end)

        token =
          Keyword.get_lazy(opts, :oauth_token, fn ->
            Pleroma.Factory.insert(:oauth_token, user: user, scopes: scopes)
          end)

        conn =
          build_conn()
          |> assign(:user, user)
          |> assign(:token, token)

        %{user: user, token: token, conn: conn}
      end

      defp request_content_type(%{conn: conn}) do
        conn = put_req_header(conn, "content-type", "multipart/form-data")
        [conn: conn]
      end

      defp empty_json_response(conn) do
        body = response(conn, 204)
        response_content_type(conn, :json)

        body
      end

      defp json_response_and_validate_schema(
             %{private: %{operation_id: op_id}} = conn,
             status
           ) do
        {spec, lookup} = OpenApiSpex.Plug.PutApiSpec.get_spec_and_operation_lookup(conn)

        content_type =
          conn
          |> Plug.Conn.get_resp_header("content-type")
          |> List.first()
          |> String.split(";")
          |> List.first()

        status = Plug.Conn.Status.code(status)

        unless lookup[op_id].responses[status] do
          err = "Response schema not found for #{status} #{conn.method} #{conn.request_path}"
          flunk(err)
        end

        schema = lookup[op_id].responses[status].content[content_type].schema
        json = if status == 204, do: empty_json_response(conn), else: json_response(conn, status)

        case OpenApiSpex.cast_value(json, schema, spec) do
          {:ok, _data} ->
            json

          {:error, errors} ->
            errors =
              Enum.map(errors, fn error ->
                message = OpenApiSpex.Cast.Error.message(error)
                path = OpenApiSpex.Cast.Error.path_to_string(error)
                "#{message} at #{path}"
              end)

            flunk(
              "Response does not conform to schema of #{op_id} operation: #{Enum.join(errors, "\n")}\n#{inspect(json)}"
            )
        end
      end

      defp json_response_and_validate_schema(conn, _status) do
        flunk("Response schema not found for #{conn.method} #{conn.request_path} #{conn.status}")
      end
    end
  end

  setup tags do
    DataCase.setup_multi_process_mode(tags)
    DataCase.setup_streamer(tags)
    DataCase.stub_pipeline()

    Mox.verify_on_exit!()

    {:ok, conn: Phoenix.ConnTest.build_conn()}
  end
end
