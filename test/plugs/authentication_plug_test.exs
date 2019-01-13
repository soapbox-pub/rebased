# Pleroma: A lightweight social networking server
# Copyright © 2017-2018 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Plugs.AuthenticationPlugTest do
  use Pleroma.Web.ConnCase, async: true

  alias Pleroma.Plugs.AuthenticationPlug
  alias Pleroma.User

  setup %{conn: conn} do
    user = %User{
      id: 1,
      name: "dude",
      password_hash: Comeonin.Pbkdf2.hashpwsalt("guy")
    }

    conn =
      conn
      |> assign(:auth_user, user)

    %{user: user, conn: conn}
  end

  test "it does nothing if a user is assigned", %{conn: conn} do
    conn =
      conn
      |> assign(:user, %User{})

    ret_conn =
      conn
      |> AuthenticationPlug.call(%{})

    assert ret_conn == conn
  end

  test "with a correct password in the credentials, it assigns the auth_user", %{conn: conn} do
    conn =
      conn
      |> assign(:auth_credentials, %{password: "guy"})
      |> AuthenticationPlug.call(%{})

    assert conn.assigns.user == conn.assigns.auth_user
  end

  test "with a wrong password in the credentials, it does nothing", %{conn: conn} do
    conn =
      conn
      |> assign(:auth_credentials, %{password: "wrong"})

    ret_conn =
      conn
      |> AuthenticationPlug.call(%{})

    assert conn == ret_conn
  end
end
