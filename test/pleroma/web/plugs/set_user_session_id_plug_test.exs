# Pleroma: A lightweight social networking server
# Copyright © 2017-2021 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.Plugs.SetUserSessionIdPlugTest do
  use Pleroma.Web.ConnCase, async: true

  alias Pleroma.Helpers.AuthHelper
  alias Pleroma.Web.Plugs.SetUserSessionIdPlug

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

    %{conn: conn}
  end

  test "doesn't do anything if the user isn't set", %{conn: conn} do
    ret_conn = SetUserSessionIdPlug.call(conn, %{})

    assert ret_conn == conn
  end

  test "sets session token basing on :token assign", %{conn: conn} do
    %{user: user, token: oauth_token} = oauth_access(["read"])

    ret_conn =
      conn
      |> assign(:user, user)
      |> assign(:token, oauth_token)
      |> SetUserSessionIdPlug.call(%{})

    assert AuthHelper.get_session_token(ret_conn) == oauth_token.token
  end
end
