# Pleroma: A lightweight social networking server
# Copyright © 2017-2019 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.OAuth.LDAPAuthorizationTest do
  use Pleroma.Web.ConnCase
  alias Pleroma.Repo
  alias Pleroma.Web.OAuth.Token
  import Pleroma.Factory
  import ExUnit.CaptureLog
  import Mock

  @skip if !Code.ensure_loaded?(:eldap), do: :skip

  clear_config_all([:ldap, :enabled]) do
    Pleroma.Config.put([:ldap, :enabled], true)
  end

  clear_config_all(Pleroma.Web.Auth.Authenticator) do
    Pleroma.Config.put(Pleroma.Web.Auth.Authenticator, Pleroma.Web.Auth.LDAPAuthenticator)
  end

  @tag @skip
  test "authorizes the existing user using LDAP credentials" do
    password = "testpassword"
    user = insert(:user, password_hash: Comeonin.Pbkdf2.hashpwsalt(password))
    app = insert(:oauth_app, scopes: ["read", "write"])

    host = Pleroma.Config.get([:ldap, :host]) |> to_charlist
    port = Pleroma.Config.get([:ldap, :port])

    with_mocks [
      {:eldap, [],
       [
         open: fn [^host], [{:port, ^port}, {:ssl, false} | _] -> {:ok, self()} end,
         simple_bind: fn _connection, _dn, ^password -> :ok end,
         close: fn _connection ->
           send(self(), :close_connection)
           :ok
         end
       ]}
    ] do
      conn =
        build_conn()
        |> post("/oauth/token", %{
          "grant_type" => "password",
          "username" => user.nickname,
          "password" => password,
          "client_id" => app.client_id,
          "client_secret" => app.client_secret
        })

      assert %{"access_token" => token} = json_response(conn, 200)

      token = Repo.get_by(Token, token: token)

      assert token.user_id == user.id
      assert_received :close_connection
    end
  end

  @tag @skip
  test "creates a new user after successful LDAP authorization" do
    password = "testpassword"
    user = build(:user)
    app = insert(:oauth_app, scopes: ["read", "write"])

    host = Pleroma.Config.get([:ldap, :host]) |> to_charlist
    port = Pleroma.Config.get([:ldap, :port])

    with_mocks [
      {:eldap, [],
       [
         open: fn [^host], [{:port, ^port}, {:ssl, false} | _] -> {:ok, self()} end,
         simple_bind: fn _connection, _dn, ^password -> :ok end,
         equalityMatch: fn _type, _value -> :ok end,
         wholeSubtree: fn -> :ok end,
         search: fn _connection, _options ->
           {:ok,
            {:eldap_search_result, [{:eldap_entry, '', [{'mail', [to_charlist(user.email)]}]}],
             []}}
         end,
         close: fn _connection ->
           send(self(), :close_connection)
           :ok
         end
       ]}
    ] do
      conn =
        build_conn()
        |> post("/oauth/token", %{
          "grant_type" => "password",
          "username" => user.nickname,
          "password" => password,
          "client_id" => app.client_id,
          "client_secret" => app.client_secret
        })

      assert %{"access_token" => token} = json_response(conn, 200)

      token = Repo.get_by(Token, token: token) |> Repo.preload(:user)

      assert token.user.nickname == user.nickname
      assert_received :close_connection
    end
  end

  @tag @skip
  test "falls back to the default authorization when LDAP is unavailable" do
    password = "testpassword"
    user = insert(:user, password_hash: Comeonin.Pbkdf2.hashpwsalt(password))
    app = insert(:oauth_app, scopes: ["read", "write"])

    host = Pleroma.Config.get([:ldap, :host]) |> to_charlist
    port = Pleroma.Config.get([:ldap, :port])

    with_mocks [
      {:eldap, [],
       [
         open: fn [^host], [{:port, ^port}, {:ssl, false} | _] -> {:error, 'connect failed'} end,
         simple_bind: fn _connection, _dn, ^password -> :ok end,
         close: fn _connection ->
           send(self(), :close_connection)
           :ok
         end
       ]}
    ] do
      log =
        capture_log(fn ->
          conn =
            build_conn()
            |> post("/oauth/token", %{
              "grant_type" => "password",
              "username" => user.nickname,
              "password" => password,
              "client_id" => app.client_id,
              "client_secret" => app.client_secret
            })

          assert %{"access_token" => token} = json_response(conn, 200)

          token = Repo.get_by(Token, token: token)

          assert token.user_id == user.id
        end)

      assert log =~ "Could not open LDAP connection: 'connect failed'"
      refute_received :close_connection
    end
  end

  @tag @skip
  test "disallow authorization for wrong LDAP credentials" do
    password = "testpassword"
    user = insert(:user, password_hash: Comeonin.Pbkdf2.hashpwsalt(password))
    app = insert(:oauth_app, scopes: ["read", "write"])

    host = Pleroma.Config.get([:ldap, :host]) |> to_charlist
    port = Pleroma.Config.get([:ldap, :port])

    with_mocks [
      {:eldap, [],
       [
         open: fn [^host], [{:port, ^port}, {:ssl, false} | _] -> {:ok, self()} end,
         simple_bind: fn _connection, _dn, ^password -> {:error, :invalidCredentials} end,
         close: fn _connection ->
           send(self(), :close_connection)
           :ok
         end
       ]}
    ] do
      conn =
        build_conn()
        |> post("/oauth/token", %{
          "grant_type" => "password",
          "username" => user.nickname,
          "password" => password,
          "client_id" => app.client_id,
          "client_secret" => app.client_secret
        })

      assert %{"error" => "Invalid credentials"} = json_response(conn, 400)
      assert_received :close_connection
    end
  end
end
