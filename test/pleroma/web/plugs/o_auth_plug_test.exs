# Pleroma: A lightweight social networking server
# Copyright © 2017-2021 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.Plugs.OAuthPlugTest do
  use Pleroma.Web.ConnCase, async: true

  alias Pleroma.Helpers.AuthHelper
  alias Pleroma.Web.OAuth.Token
  alias Pleroma.Web.OAuth.Token.Strategy.Revoke
  alias Pleroma.Web.Plugs.OAuthPlug
  alias Plug.Session

  import Pleroma.Factory

  setup %{conn: conn} do
    user = insert(:user)
    {:ok, oauth_token} = Token.create(insert(:oauth_app), user)
    %{user: user, token: oauth_token, conn: conn}
  end

  test "it does nothing if a user is assigned", %{conn: conn} do
    conn = assign(conn, :user, %Pleroma.User{})
    ret_conn = OAuthPlug.call(conn, %{})

    assert ret_conn == conn
  end

  test "with valid token (uppercase) in auth header, it assigns the user", %{conn: conn} = opts do
    conn =
      conn
      |> put_req_header("authorization", "BEARER #{opts[:token].token}")
      |> OAuthPlug.call(%{})

    assert conn.assigns[:user] == opts[:user]
  end

  test "with valid token (downcase) in auth header, it assigns the user", %{conn: conn} = opts do
    conn =
      conn
      |> put_req_header("authorization", "bearer #{opts[:token].token}")
      |> OAuthPlug.call(%{})

    assert conn.assigns[:user] == opts[:user]
  end

  test "with valid token (downcase) in url parameters, it assigns the user", opts do
    conn =
      :get
      |> build_conn("/?access_token=#{opts[:token].token}")
      |> put_req_header("content-type", "application/json")
      |> fetch_query_params()
      |> OAuthPlug.call(%{})

    assert conn.assigns[:user] == opts[:user]
  end

  test "with valid token (downcase) in body parameters, it assigns the user", opts do
    conn =
      :post
      |> build_conn("/api/v1/statuses", access_token: opts[:token].token, status: "test")
      |> OAuthPlug.call(%{})

    assert conn.assigns[:user] == opts[:user]
  end

  test "with invalid token, it does not assign the user", %{conn: conn} do
    conn =
      conn
      |> put_req_header("authorization", "bearer TTTTT")
      |> OAuthPlug.call(%{})

    refute conn.assigns[:user]
  end

  describe "with :oauth_token in session, " do
    setup %{token: oauth_token, conn: conn} do
      session_opts = [
        store: :cookie,
        key: "_test",
        signing_salt: "cooldude"
      ]

      conn =
        conn
        |> Session.call(Session.init(session_opts))
        |> fetch_session()
        |> AuthHelper.put_session_token(oauth_token.token)

      %{conn: conn}
    end

    test "if session-stored token matches a valid OAuth token, assigns :user and :token", %{
      conn: conn,
      user: user,
      token: oauth_token
    } do
      conn = OAuthPlug.call(conn, %{})

      assert conn.assigns.user && conn.assigns.user.id == user.id
      assert conn.assigns.token && conn.assigns.token.id == oauth_token.id
    end

    test "if session-stored token matches an expired OAuth token, does nothing", %{
      conn: conn,
      token: oauth_token
    } do
      expired_valid_until = NaiveDateTime.add(NaiveDateTime.utc_now(), -3600 * 24, :second)

      oauth_token
      |> Ecto.Changeset.change(valid_until: expired_valid_until)
      |> Pleroma.Repo.update()

      ret_conn = OAuthPlug.call(conn, %{})
      assert ret_conn == conn
    end

    test "if session-stored token matches a revoked OAuth token, does nothing", %{
      conn: conn,
      token: oauth_token
    } do
      Revoke.revoke(oauth_token)

      ret_conn = OAuthPlug.call(conn, %{})
      assert ret_conn == conn
    end
  end
end
