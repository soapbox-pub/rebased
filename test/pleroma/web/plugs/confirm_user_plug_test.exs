# Pleroma: A lightweight social networking server
# Copyright © 2017-2020 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.Plugs.ConfirmUserPlugTest do
  use Pleroma.Web.ConnCase, async: true
  alias Pleroma.User
  alias Pleroma.Web.Plugs.ConfirmUserPlug
  import Pleroma.Factory

  test "it confirms an unconfirmed user", %{conn: conn} do
    %User{id: user_id} = user = insert(:user, confirmation_pending: true)

    conn =
      conn
      |> assign(:user, user)
      |> ConfirmUserPlug.call(%{})

    assert %Plug.Conn{assigns: %{user: %User{id: ^user_id, confirmation_pending: false}}} = conn
    assert %User{confirmation_pending: false} = User.get_by_id(user_id)
  end

  test "it does nothing without an unconfirmed user", %{conn: conn} do
    assert conn == ConfirmUserPlug.call(conn, %{})

    user = insert(:user, confirmation_pending: false)
    conn = assign(conn, :user, user)
    assert conn == ConfirmUserPlug.call(conn, %{})
  end
end
