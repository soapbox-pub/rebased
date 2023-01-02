# Pleroma: A lightweight social networking server
# Copyright © 2017-2022 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.AdminAPI.MediaProxyCacheControllerTest do
  use Pleroma.Web.ConnCase

  import Pleroma.Factory
  import Mock

  alias Pleroma.Web.MediaProxy

  setup do: clear_config([:media_proxy])

  setup do
    admin = insert(:user, is_admin: true)
    token = insert(:oauth_admin_token, user: admin)

    conn =
      build_conn()
      |> assign(:user, admin)
      |> assign(:token, token)

    clear_config([:media_proxy, :enabled], true)
    clear_config([:media_proxy, :invalidation, :enabled], true)
    clear_config([:media_proxy, :invalidation, :provider], MediaProxy.Invalidation.Script)

    {:ok, %{admin: admin, token: token, conn: conn}}
  end

  describe "GET /api/pleroma/admin/media_proxy_caches" do
    test "shows banned MediaProxy URLs", %{conn: conn} do
      MediaProxy.put_in_banned_urls([
        "http://localhost:4001/media/a688346.jpg",
        "http://localhost:4001/media/fb1f4d.jpg"
      ])

      MediaProxy.put_in_banned_urls("http://localhost:4001/media/gb1f44.jpg")
      MediaProxy.put_in_banned_urls("http://localhost:4001/media/tb13f47.jpg")
      MediaProxy.put_in_banned_urls("http://localhost:4001/media/wb1f46.jpg")

      response =
        conn
        |> get("/api/pleroma/admin/media_proxy_caches?page_size=2")
        |> json_response_and_validate_schema(200)

      assert response["page_size"] == 2
      assert response["count"] == 5

      results = response["urls"]

      response =
        conn
        |> get("/api/pleroma/admin/media_proxy_caches?page_size=2&page=2")
        |> json_response_and_validate_schema(200)

      assert response["page_size"] == 2
      assert response["count"] == 5

      results = results ++ response["urls"]

      response =
        conn
        |> get("/api/pleroma/admin/media_proxy_caches?page_size=2&page=3")
        |> json_response_and_validate_schema(200)

      results = results ++ response["urls"]

      assert results |> Enum.sort() ==
               [
                 "http://localhost:4001/media/wb1f46.jpg",
                 "http://localhost:4001/media/gb1f44.jpg",
                 "http://localhost:4001/media/tb13f47.jpg",
                 "http://localhost:4001/media/fb1f4d.jpg",
                 "http://localhost:4001/media/a688346.jpg"
               ]
               |> Enum.sort()
    end

    test "search banned MediaProxy URLs", %{conn: conn} do
      MediaProxy.put_in_banned_urls([
        "http://localhost:4001/media/a688346.jpg",
        "http://localhost:4001/media/ff44b1f4d.jpg"
      ])

      MediaProxy.put_in_banned_urls("http://localhost:4001/media/gb1f44.jpg")
      MediaProxy.put_in_banned_urls("http://localhost:4001/media/tb13f47.jpg")
      MediaProxy.put_in_banned_urls("http://localhost:4001/media/wb1f46.jpg")

      response =
        conn
        |> get("/api/pleroma/admin/media_proxy_caches?page_size=2&query=F44")
        |> json_response_and_validate_schema(200)

      assert response["urls"] |> Enum.sort() == [
               "http://localhost:4001/media/ff44b1f4d.jpg",
               "http://localhost:4001/media/gb1f44.jpg"
             ]

      assert response["page_size"] == 2
      assert response["count"] == 2
    end
  end

  describe "POST /api/pleroma/admin/media_proxy_caches/delete" do
    test "deleted MediaProxy URLs from banned", %{conn: conn} do
      MediaProxy.put_in_banned_urls([
        "http://localhost:4001/media/a688346.jpg",
        "http://localhost:4001/media/fb1f4d.jpg"
      ])

      conn
      |> put_req_header("content-type", "application/json")
      |> post("/api/pleroma/admin/media_proxy_caches/delete", %{
        urls: ["http://localhost:4001/media/a688346.jpg"]
      })
      |> json_response_and_validate_schema(200)

      refute MediaProxy.in_banned_urls("http://localhost:4001/media/a688346.jpg")
      assert MediaProxy.in_banned_urls("http://localhost:4001/media/fb1f4d.jpg")
    end
  end

  describe "POST /api/pleroma/admin/media_proxy_caches/purge" do
    test "perform invalidates cache of MediaProxy", %{conn: conn} do
      urls = [
        "http://example.com/media/a688346.jpg",
        "http://example.com/media/fb1f4d.jpg"
      ]

      with_mocks [
        {MediaProxy.Invalidation.Script, [],
         [
           purge: fn _, _ -> {"ok", 0} end
         ]}
      ] do
        conn
        |> put_req_header("content-type", "application/json")
        |> post("/api/pleroma/admin/media_proxy_caches/purge", %{urls: urls, ban: false})
        |> json_response_and_validate_schema(200)

        refute MediaProxy.in_banned_urls("http://example.com/media/a688346.jpg")
        refute MediaProxy.in_banned_urls("http://example.com/media/fb1f4d.jpg")
      end
    end

    test "perform invalidates cache of MediaProxy and adds url to banned", %{conn: conn} do
      urls = [
        "http://example.com/media/a688346.jpg",
        "http://example.com/media/fb1f4d.jpg"
      ]

      with_mocks [{MediaProxy.Invalidation.Script, [], [purge: fn _, _ -> {"ok", 0} end]}] do
        conn
        |> put_req_header("content-type", "application/json")
        |> post(
          "/api/pleroma/admin/media_proxy_caches/purge",
          %{urls: urls, ban: true}
        )
        |> json_response_and_validate_schema(200)

        assert MediaProxy.in_banned_urls("http://example.com/media/a688346.jpg")
        assert MediaProxy.in_banned_urls("http://example.com/media/fb1f4d.jpg")
      end
    end
  end
end
