# Pleroma: A lightweight social networking server
# Copyright © 2017-2020 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.Plugs.SessionAuthenticationPlugTest do
  use Pleroma.Web.ConnCase, async: true

  alias Pleroma.User
  alias Pleroma.Web.Plugs.OAuthScopesPlug
  alias Pleroma.Web.Plugs.PlugHelper
  alias Pleroma.Web.Plugs.SessionAuthenticationPlug

  setup %{conn: conn} do
    session_opts = [
      store: :cookie,
      key: "_test",
      signing_salt: "cooldude"
    ]

    conn =
      conn
      |> Plug.Session.call(Plug.Session.init(session_opts))
      |> fetch_session()
      |> assign(:auth_user, %User{id: 1})

    %{conn: conn}
  end

  test "it does nothing if a user is assigned", %{conn: conn} do
    conn = assign(conn, :user, %User{})
    ret_conn = SessionAuthenticationPlug.call(conn, %{})

    assert ret_conn == conn
  end

  # Scenario: requester has the cookie and knows the username (not necessarily knows the password)
  test "if the auth_user has the same id as the user_id in the session, it assigns the user", %{
    conn: conn
  } do
    conn =
      conn
      |> put_session(:user_id, conn.assigns.auth_user.id)
      |> SessionAuthenticationPlug.call(%{})

    assert conn.assigns.user == conn.assigns.auth_user
    assert conn.assigns.token == nil
    assert PlugHelper.plug_skipped?(conn, OAuthScopesPlug)
  end

  # Scenario: requester has the cookie but doesn't know the username
  test "if the auth_user has a different id as the user_id in the session, it does nothing", %{
    conn: conn
  } do
    conn = put_session(conn, :user_id, -1)
    ret_conn = SessionAuthenticationPlug.call(conn, %{})

    assert ret_conn == conn
  end

  test "if the session does not contain user_id, it does nothing", %{
    conn: conn
  } do
    assert conn == SessionAuthenticationPlug.call(conn, %{})
  end
end
