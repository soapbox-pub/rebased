defmodule Pleroma.Plugs.UserEnabledPlugTest do
  use Pleroma.Web.ConnCase, async: true

  alias Pleroma.Plugs.UserEnabledPlug
  alias Pleroma.User

  test "doesn't do anything if the user isn't set", %{conn: conn} do
    ret_conn =
      conn
      |> UserEnabledPlug.call(%{})

    assert ret_conn == conn
  end

  test "with a user that is deactivated, it removes that user", %{conn: conn} do
    conn =
      conn
      |> assign(:user, %User{info: %{"deactivated" => true}})
      |> UserEnabledPlug.call(%{})

    assert conn.assigns.user == nil
  end

  test "with a user that is not deactivated, it does nothing", %{conn: conn} do
    conn =
      conn
      |> assign(:user, %User{})

    ret_conn =
      conn
      |> UserEnabledPlug.call(%{})

    assert conn == ret_conn
  end
end
