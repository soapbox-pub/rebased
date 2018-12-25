# Pleroma: A lightweight social networking server
# Copyright © 2017-2018 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Plugs.LegacyAuthenticationPlugTest do
  use Pleroma.Web.ConnCase, async: true

  alias Pleroma.Plugs.LegacyAuthenticationPlug
  alias Pleroma.User

  import Mock

  setup do
    # password is "password"
    user = %User{
      id: 1,
      name: "dude",
      password_hash:
        "$6$9psBWV8gxkGOZWBz$PmfCycChoxeJ3GgGzwvhlgacb9mUoZ.KUXNCssekER4SJ7bOK53uXrHNb2e4i8yPFgSKyzaW9CcmrDXWIEMtD1"
    }

    %{user: user}
  end

  test "it does nothing if a user is assigned", %{conn: conn, user: user} do
    conn =
      conn
      |> assign(:auth_credentials, %{username: "dude", password: "password"})
      |> assign(:auth_user, user)
      |> assign(:user, %User{})

    ret_conn =
      conn
      |> LegacyAuthenticationPlug.call(%{})

    assert ret_conn == conn
  end

  test "it authenticates the auth_user if present and password is correct and resets the password",
       %{
         conn: conn,
         user: user
       } do
    conn =
      conn
      |> assign(:auth_credentials, %{username: "dude", password: "password"})
      |> assign(:auth_user, user)

    conn =
      with_mock User,
        reset_password: fn user, %{password: password, password_confirmation: password} ->
          send(self(), :reset_password)
          {:ok, user}
        end do
        conn
        |> LegacyAuthenticationPlug.call(%{})
      end

    assert_received :reset_password
    assert conn.assigns.user == user
  end

  test "it does nothing if the password is wrong", %{
    conn: conn,
    user: user
  } do
    conn =
      conn
      |> assign(:auth_credentials, %{username: "dude", password: "wrong_password"})
      |> assign(:auth_user, user)

    ret_conn =
      conn
      |> LegacyAuthenticationPlug.call(%{})

    assert conn == ret_conn
  end

  test "with no credentials or user it does nothing", %{conn: conn} do
    ret_conn =
      conn
      |> LegacyAuthenticationPlug.call(%{})

    assert ret_conn == conn
  end
end
