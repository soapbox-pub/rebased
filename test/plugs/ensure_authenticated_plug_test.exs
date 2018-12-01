defmodule Pleroma.Plugs.EnsureAuthenticatedPlugTest do
  use Pleroma.Web.ConnCase, async: true

  alias Pleroma.Plugs.EnsureAuthenticatedPlug
  alias Pleroma.User

  test "it halts if no user is assigned", %{conn: conn} do
    conn =
      conn
      |> EnsureAuthenticatedPlug.call(%{})

    assert conn.status == 403
    assert conn.halted == true
  end

  test "it continues if a user is assigned", %{conn: conn} do
    conn =
      conn
      |> assign(:user, %User{})

    ret_conn =
      conn
      |> EnsureAuthenticatedPlug.call(%{})

    assert ret_conn == conn
  end
end
