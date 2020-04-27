# Pleroma: A lightweight social networking server
# Copyright © 2017-2020 Pleroma Authors <https://pleroma.social/>
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

  using do
    quote do
      # Import conveniences for testing with connections
      use Phoenix.ConnTest
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

      defp json_response_and_validate_schema(
             %{
               private: %{
                 open_api_spex: %{operation_id: op_id, operation_lookup: lookup, spec: spec}
               }
             } = conn,
             status
           ) do
        content_type =
          conn
          |> Plug.Conn.get_resp_header("content-type")
          |> List.first()
          |> String.split(";")
          |> List.first()

        status = Plug.Conn.Status.code(status)

        unless lookup[op_id].responses[status] do
          err = "Response schema not found for #{conn.status} #{conn.method} #{conn.request_path}"
          flunk(err)
        end

        schema = lookup[op_id].responses[status].content[content_type].schema
        json = json_response(conn, status)

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
              "Response does not conform to schema of #{op_id} operation: #{
                Enum.join(errors, "\n")
              }\n#{inspect(json)}"
            )
        end
      end

      defp json_response_and_validate_schema(conn, _status) do
        flunk("Response schema not found for #{conn.method} #{conn.request_path} #{conn.status}")
      end

      defp ensure_federating_or_authenticated(conn, url, user) do
        initial_setting = Config.get([:instance, :federating])
        on_exit(fn -> Config.put([:instance, :federating], initial_setting) end)

        Config.put([:instance, :federating], false)

        conn
        |> get(url)
        |> response(403)

        conn
        |> assign(:user, user)
        |> get(url)
        |> response(200)

        Config.put([:instance, :federating], true)

        conn
        |> get(url)
        |> response(200)
      end
    end
  end

  setup tags do
    Cachex.clear(:user_cache)
    Cachex.clear(:object_cache)
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(Pleroma.Repo)

    unless tags[:async] do
      Ecto.Adapters.SQL.Sandbox.mode(Pleroma.Repo, {:shared, self()})
    end

    if tags[:needs_streamer] do
      start_supervised(Pleroma.Web.Streamer.supervisor())
    end

    {:ok, conn: Phoenix.ConnTest.build_conn()}
  end
end
