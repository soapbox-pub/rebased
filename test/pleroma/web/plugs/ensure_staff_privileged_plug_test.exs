# Pleroma: A lightweight social networking server
# Copyright © 2017-2022 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.Plugs.EnsureStaffPrivilegedPlugTest do
  use Pleroma.Web.ConnCase, async: true

  alias Pleroma.Web.Plugs.EnsureStaffPrivilegedPlug
  import Pleroma.Factory

  test "accepts a user that is an admin" do
    user = insert(:user, is_admin: true)

    conn = assign(build_conn(), :user, user)

    ret_conn = EnsureStaffPrivilegedPlug.call(conn, %{})

    assert conn == ret_conn
  end

  test "accepts a user that is a moderator when :privileged_staff is enabled" do
    clear_config([:instance, :privileged_staff], true)
    user = insert(:user, is_moderator: true)

    conn = assign(build_conn(), :user, user)

    ret_conn = EnsureStaffPrivilegedPlug.call(conn, %{})

    assert conn == ret_conn
  end

  test "denies a user that is a moderator when :privileged_staff is disabled" do
    clear_config([:instance, :privileged_staff], false)
    user = insert(:user, is_moderator: true)

    conn =
      build_conn()
      |> assign(:user, user)
      |> EnsureStaffPrivilegedPlug.call(%{})

    assert conn.status == 403
  end

  test "denies a user that isn't a staff member" do
    user = insert(:user)

    conn =
      build_conn()
      |> assign(:user, user)
      |> EnsureStaffPrivilegedPlug.call(%{})

    assert conn.status == 403
  end

  test "denies when a user isn't set" do
    conn = EnsureStaffPrivilegedPlug.call(build_conn(), %{})

    assert conn.status == 403
  end
end
