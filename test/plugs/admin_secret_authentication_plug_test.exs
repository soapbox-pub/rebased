defmodule Pleroma.Plugs.AdminSecretAuthenticationPlugTest do
  use Pleroma.Web.ConnCase, async: true
  import Pleroma.Factory

  alias Pleroma.Plugs.AdminSecretAuthenticationPlug

  test "does nothing if a user is assigned", %{conn: conn} do
    user = insert(:user)

    conn =
      conn
      |> assign(:user, user)

    ret_conn =
      conn
      |> AdminSecretAuthenticationPlug.call(%{})

    assert conn == ret_conn
  end

  test "with secret set and given in the 'admin_token' parameter, it assigns an admin user", %{
    conn: conn
  } do
    Pleroma.Config.put(:admin_token, "password123")

    conn =
      %{conn | params: %{"admin_token" => "wrong_password"}}
      |> AdminSecretAuthenticationPlug.call(%{})

    refute conn.assigns[:user]

    conn =
      %{conn | params: %{"admin_token" => "password123"}}
      |> AdminSecretAuthenticationPlug.call(%{})

    assert conn.assigns[:user].info.is_admin
  end
end
