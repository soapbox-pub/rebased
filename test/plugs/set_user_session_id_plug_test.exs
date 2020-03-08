# Pleroma: A lightweight social networking server
# Copyright © 2017-2020 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Plugs.SetUserSessionIdPlugTest do
  use Pleroma.Web.ConnCase, async: true

  alias Pleroma.Plugs.SetUserSessionIdPlug
  alias Pleroma.User

  setup %{conn: conn} do
    session_opts = [
      store: :cookie,
      key: "_test",
      signing_salt: "cooldude"
    ]

    conn =
      conn
      |> Plug.Session.call(Plug.Session.init(session_opts))
      |> fetch_session

    %{conn: conn}
  end

  test "doesn't do anything if the user isn't set", %{conn: conn} do
    ret_conn =
      conn
      |> SetUserSessionIdPlug.call(%{})

    assert ret_conn == conn
  end

  test "sets the user_id in the session to the user id of the user assign", %{conn: conn} do
    Code.ensure_compiled(Pleroma.User)

    conn =
      conn
      |> assign(:user, %User{id: 1})
      |> SetUserSessionIdPlug.call(%{})

    id = get_session(conn, :user_id)
    assert id == 1
  end
end
