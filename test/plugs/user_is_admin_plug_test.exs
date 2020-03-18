# Pleroma: A lightweight social networking server
# Copyright © 2017-2020 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Plugs.UserIsAdminPlugTest do
  use Pleroma.Web.ConnCase, async: true

  alias Pleroma.Plugs.UserIsAdminPlug
  import Pleroma.Factory

  describe "unless [:auth, :enforce_oauth_admin_scope_usage]," do
    clear_config([:auth, :enforce_oauth_admin_scope_usage], false)

    test "accepts a user that is an admin" do
      user = insert(:user, is_admin: true)

      conn = assign(build_conn(), :user, user)

      ret_conn = UserIsAdminPlug.call(conn, %{})

      assert conn == ret_conn
    end

    test "denies a user that isn't an admin" do
      user = insert(:user)

      conn =
        build_conn()
        |> assign(:user, user)
        |> UserIsAdminPlug.call(%{})

      assert conn.status == 403
    end

    test "denies when a user isn't set" do
      conn = UserIsAdminPlug.call(build_conn(), %{})

      assert conn.status == 403
    end
  end

  describe "with [:auth, :enforce_oauth_admin_scope_usage]," do
    clear_config([:auth, :enforce_oauth_admin_scope_usage], true)

    setup do
      admin_user = insert(:user, is_admin: true)
      non_admin_user = insert(:user, is_admin: false)
      blank_user = nil

      {:ok, %{users: [admin_user, non_admin_user, blank_user]}}
    end

    test "if token has any of admin scopes, accepts a user that is an admin", %{conn: conn} do
      user = insert(:user, is_admin: true)
      token = insert(:oauth_token, user: user, scopes: ["admin:something"])

      conn =
        conn
        |> assign(:user, user)
        |> assign(:token, token)

      ret_conn = UserIsAdminPlug.call(conn, %{})

      assert conn == ret_conn
    end

    test "if token has any of admin scopes, denies a user that isn't an admin", %{conn: conn} do
      user = insert(:user, is_admin: false)
      token = insert(:oauth_token, user: user, scopes: ["admin:something"])

      conn =
        conn
        |> assign(:user, user)
        |> assign(:token, token)
        |> UserIsAdminPlug.call(%{})

      assert conn.status == 403
    end

    test "if token has any of admin scopes, denies when a user isn't set", %{conn: conn} do
      token = insert(:oauth_token, scopes: ["admin:something"])

      conn =
        conn
        |> assign(:user, nil)
        |> assign(:token, token)
        |> UserIsAdminPlug.call(%{})

      assert conn.status == 403
    end

    test "if token lacks admin scopes, denies users regardless of is_admin flag",
         %{users: users} do
      for user <- users do
        token = insert(:oauth_token, user: user)

        conn =
          build_conn()
          |> assign(:user, user)
          |> assign(:token, token)
          |> UserIsAdminPlug.call(%{})

        assert conn.status == 403
      end
    end

    test "if token is missing, denies users regardless of is_admin flag", %{users: users} do
      for user <- users do
        conn =
          build_conn()
          |> assign(:user, user)
          |> assign(:token, nil)
          |> UserIsAdminPlug.call(%{})

        assert conn.status == 403
      end
    end
  end
end
