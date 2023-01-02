# Pleroma: A lightweight social networking server
# Copyright © 2017-2022 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.Plugs.UserIsStaffPlugTest do
  use Pleroma.Web.ConnCase, async: true

  alias Pleroma.Web.Plugs.UserIsStaffPlug
  import Pleroma.Factory

  test "accepts a user that is an admin" do
    user = insert(:user, is_admin: true)

    conn = assign(build_conn(), :user, user)

    ret_conn = UserIsStaffPlug.call(conn, %{})

    assert conn == ret_conn
  end

  test "accepts a user that is a moderator" do
    user = insert(:user, is_moderator: true)

    conn = assign(build_conn(), :user, user)

    ret_conn = UserIsStaffPlug.call(conn, %{})

    assert conn == ret_conn
  end

  test "denies a user that isn't a staff member" do
    user = insert(:user)

    conn =
      build_conn()
      |> assign(:user, user)
      |> UserIsStaffPlug.call(%{})

    assert conn.status == 403
  end

  test "denies when a user isn't set" do
    conn = UserIsStaffPlug.call(build_conn(), %{})

    assert conn.status == 403
  end
end
