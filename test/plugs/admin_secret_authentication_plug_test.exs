# Pleroma: A lightweight social networking server
# Copyright © 2017-2020 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

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

  describe "when secret set it assigns an admin user" do
    clear_config([:admin_token])

    test "with `admin_token` query parameter", %{conn: conn} do
      Pleroma.Config.put(:admin_token, "password123")

      conn =
        %{conn | params: %{"admin_token" => "wrong_password"}}
        |> AdminSecretAuthenticationPlug.call(%{})

      refute conn.assigns[:user]

      conn =
        %{conn | params: %{"admin_token" => "password123"}}
        |> AdminSecretAuthenticationPlug.call(%{})

      assert conn.assigns[:user].is_admin
    end

    test "with `x-admin-token` HTTP header", %{conn: conn} do
      Pleroma.Config.put(:admin_token, "☕️")

      conn =
        conn
        |> put_req_header("x-admin-token", "🥛")
        |> AdminSecretAuthenticationPlug.call(%{})

      refute conn.assigns[:user]

      conn =
        conn
        |> put_req_header("x-admin-token", "☕️")
        |> AdminSecretAuthenticationPlug.call(%{})

      assert conn.assigns[:user].is_admin
    end
  end
end
