# Pleroma: A lightweight social networking server
# Copyright © 2017-2020 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.AdminAPI.MediaProxyCacheControllerTest do
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

  describe "GET /api/pleroma/admin/media_proxy_caches" do
    test "shows banned MediaProxy URLs", %{conn: conn} do
      response =
        conn
        |> get("/api/pleroma/admin/media_proxy_caches")
        |> json_response_and_validate_schema(200)

      assert response["urls"] == []
    end
  end

  describe "DELETE /api/pleroma/admin/media_proxy_caches/delete" do
    test "deleted MediaProxy URLs from banned", %{conn: conn} do
      response =
        conn
        |> put_req_header("content-type", "application/json")
        |> post("/api/pleroma/admin/media_proxy_caches/delete", %{
          urls: ["http://example.com/media/a688346.jpg", "http://example.com/media/fb1f4d.jpg"]
        })
        |> json_response_and_validate_schema(200)

      assert response["urls"] == [
               "http://example.com/media/a688346.jpg",
               "http://example.com/media/fb1f4d.jpg"
             ]
    end
  end

  describe "PURGE /api/pleroma/admin/media_proxy_caches/purge" do
    test "perform invalidates cache of MediaProxy", %{conn: conn} do
      response =
        conn
        |> put_req_header("content-type", "application/json")
        |> post("/api/pleroma/admin/media_proxy_caches/purge", %{
          urls: ["http://example.com/media/a688346.jpg", "http://example.com/media/fb1f4d.jpg"]
        })
        |> json_response_and_validate_schema(200)

      assert response["urls"] == [
               "http://example.com/media/a688346.jpg",
               "http://example.com/media/fb1f4d.jpg"
             ]
    end
  end
end
