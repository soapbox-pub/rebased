# Pleroma: A lightweight social networking server
# Copyright © 2017-2022 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.AdminAPI.AnnouncementControllerTest do
  use Pleroma.Web.ConnCase

  import Pleroma.Factory

  setup do
    admin = insert(:user, is_admin: true)
    token = insert(:oauth_admin_token, user: admin)

    conn =
      build_conn()
      |> assign(:user, admin)
      |> assign(:token, token)

    {:ok, %{admin: admin, token: token, conn: conn}}
  end

  describe "GET /api/v1/pleroma/admin/announcements" do
    test "it lists all announcements", %{conn: conn} do
      %{id: id} = insert(:announcement)

      response =
        conn
        |> get("/api/v1/pleroma/admin/announcements")
        |> json_response_and_validate_schema(:ok)

      assert [%{"id" => ^id}] = response
    end
  end

  describe "GET /api/v1/pleroma/admin/announcements/:id" do
    test "it displays one announcement", %{conn: conn} do
      %{id: id} = insert(:announcement)

      response =
        conn
        |> get("/api/v1/pleroma/admin/announcements/#{id}")
        |> json_response_and_validate_schema(:ok)

      assert %{"id" => ^id} = response
    end

    test "it returns not found for non-existent id", %{conn: conn} do
      %{id: id} = insert(:announcement)

      _response =
        conn
        |> get("/api/v1/pleroma/admin/announcements/#{id}xxx")
        |> json_response_and_validate_schema(:not_found)
    end
  end

  describe "DELETE /api/v1/pleroma/admin/announcements/:id" do
    test "it deletes specified announcement", %{conn: conn} do
      %{id: id} = insert(:announcement)

      _response =
        conn
        |> delete("/api/v1/pleroma/admin/announcements/#{id}")
        |> json_response_and_validate_schema(:ok)
    end

    test "it returns not found for non-existent id", %{conn: conn} do
      %{id: id} = insert(:announcement)

      _response =
        conn
        |> get("/api/v1/pleroma/admin/announcements/#{id}xxx")
        |> json_response_and_validate_schema(:not_found)

      assert %{id: ^id} = Pleroma.Announcement.get_by_id(id)
    end
  end

  describe "POST /api/v1/pleroma/admin/announcements" do
    test "it creates an announcement", %{conn: conn} do
      content = "test post announcement api"

      response =
        conn
        |> put_req_header("content-type", "application/json")
        |> post("/api/v1/pleroma/admin/announcements", %{
          "content" => content
        })
        |> json_response_and_validate_schema(:ok)

      assert %{"content" => ^content} = response
    end
  end
end
