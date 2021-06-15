# Pleroma: A lightweight social networking server
# Copyright © 2017-2021 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.AdminAPI.EmailListControllerTest do
  use Pleroma.Web.ConnCase, async: true

  import Pleroma.Factory

  defp admin_setup do
    admin = insert(:user, is_admin: true)
    token = insert(:oauth_admin_token, user: admin)

    conn =
      build_conn()
      |> assign(:user, admin)
      |> assign(:token, token)

    {:ok, %{admin: admin, token: token, conn: conn}}
  end

  defp user_setup do
    user = insert(:user)
    token = insert(:oauth_token, user: user)

    conn =
      build_conn()
      |> assign(:user, user)
      |> assign(:token, token)

    {:ok, %{user: user, token: token, conn: conn}}
  end

  describe "GET /api/v1/pleroma/admin/email_list/subscribers.csv" do
    setup do: admin_setup()

    test "returns a CSV", %{conn: conn} do
      result =
        conn
        |> get("/api/v1/pleroma/admin/email_list/subscribers.csv")
        |> response(200)

      assert result
    end
  end

  describe "GET /api/v1/pleroma/admin/email_list/subscribers.csv unauthorized" do
    setup do: user_setup()

    test "returns 403", %{conn: conn} do
      conn
      |> get("/api/v1/pleroma/admin/email_list/subscribers.csv")
      |> response(403)
    end
  end

  describe "GET /api/v1/pleroma/admin/email_list/unsubscribers.csv" do
    setup do: admin_setup()

    test "returns a CSV", %{conn: conn} do
      result =
        conn
        |> get("/api/v1/pleroma/admin/email_list/unsubscribers.csv")
        |> response(200)

      assert result
    end
  end

  describe "GET /api/v1/pleroma/admin/email_list/unsubscribers.csv unauthorized" do
    setup do: user_setup()

    test "returns 403", %{conn: conn} do
      conn
      |> get("/api/v1/pleroma/admin/email_list/unsubscribers.csv")
      |> response(403)
    end
  end
end
