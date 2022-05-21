# Pleroma: A lightweight social networking server
# Copyright © 2017-2022 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.Plugs.EnsurePrivilegedPlugTest do
  use Pleroma.Web.ConnCase, async: true

  alias Pleroma.Web.Plugs.EnsurePrivilegedPlug
  import Pleroma.Factory

  test "denies a user that isn't moderator or admin" do
    clear_config([:instance, :admin_privileges], [])
    user = insert(:user)

    conn =
      build_conn()
      |> assign(:user, user)
      |> EnsurePrivilegedPlug.call(:cofe)

    assert conn.status == 403
  end

  test "accepts an admin that is privileged" do
    clear_config([:instance, :admin_privileges], [:cofe])
    user = insert(:user, is_admin: true)
    conn = assign(build_conn(), :user, user)

    ret_conn = EnsurePrivilegedPlug.call(conn, :cofe)

    assert conn == ret_conn
  end

  test "denies an admin that isn't privileged" do
    clear_config([:instance, :admin_privileges], [:suya])
    user = insert(:user, is_admin: true)

    conn =
      build_conn()
      |> assign(:user, user)
      |> EnsurePrivilegedPlug.call(:cofe)

    assert conn.status == 403
  end

  test "accepts a moderator that is privileged" do
    clear_config([:instance, :moderator_privileges], [:cofe])
    user = insert(:user, is_moderator: true)
    conn = assign(build_conn(), :user, user)

    ret_conn = EnsurePrivilegedPlug.call(conn, :cofe)

    assert conn == ret_conn
  end

  test "denies a moderator that isn't privileged" do
    clear_config([:instance, :moderator_privileges], [:suya])
    user = insert(:user, is_moderator: true)

    conn =
      build_conn()
      |> assign(:user, user)
      |> EnsurePrivilegedPlug.call(:cofe)

    assert conn.status == 403
  end

  test "accepts for a priviledged role even if other role isn't priviledged" do
    clear_config([:instance, :admin_privileges], [:cofe])
    clear_config([:instance, :moderator_privileges], [])
    user = insert(:user, is_admin: true, is_moderator: true)
    conn = assign(build_conn(), :user, user)

    ret_conn = EnsurePrivilegedPlug.call(conn, :cofe)

    # priviledged through admin role
    assert conn == ret_conn

    clear_config([:instance, :admin_privileges], [])
    clear_config([:instance, :moderator_privileges], [:cofe])
    user = insert(:user, is_admin: true, is_moderator: true)
    conn = assign(build_conn(), :user, user)

    ret_conn = EnsurePrivilegedPlug.call(conn, :cofe)

    # priviledged through moderator role
    assert conn == ret_conn
  end

  test "denies when no user is set" do
    conn =
      build_conn()
      |> EnsurePrivilegedPlug.call(:cofe)

    assert conn.status == 403
  end
end
