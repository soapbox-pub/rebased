defmodule Pleroma.Plugs.LegacyAuthenticationPlugTest do
  use Pleroma.Web.ConnCase, async: true

  alias Pleroma.Plugs.LegacyAuthenticationPlug
  alias Pleroma.User

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

  test "it authenticates the auth_user if present and password is correct", %{
    conn: conn,
    user: user
  } do
    conn =
      conn
      |> assign(:auth_credentials, %{username: "dude", password: "password"})
      |> assign(:auth_user, user)

    conn =
      conn
      |> LegacyAuthenticationPlug.call(%{})

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
