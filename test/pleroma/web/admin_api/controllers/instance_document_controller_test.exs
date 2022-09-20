# Pleroma: A lightweight social networking server
# Copyright © 2017-2022 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.AdminAPI.InstanceDocumentControllerTest do
  use Pleroma.Web.ConnCase
  import Pleroma.Factory

  @dir "test/tmp/instance_static"
  @default_instance_panel ~s(<p>Welcome to <a href="https://pleroma.social" target="_blank">Pleroma!</a></p>)

  setup do
    File.mkdir_p!(@dir)
    on_exit(fn -> File.rm_rf(@dir) end)
  end

  setup do: clear_config([:instance, :static_dir], @dir)

  setup do
    admin = insert(:user, is_admin: true)
    token = insert(:oauth_admin_token, user: admin)

    conn =
      build_conn()
      |> assign(:user, admin)
      |> assign(:token, token)

    {:ok, %{admin: admin, token: token, conn: conn}}
  end

  describe "GET /api/pleroma/admin/instance_document/:name" do
    test "return the instance document url", %{conn: conn} do
      conn = get(conn, "/api/pleroma/admin/instance_document/instance-panel")

      assert content = html_response(conn, 200)
      assert String.contains?(content, @default_instance_panel)
    end

    test "it returns 403 if requested by a non-admin" do
      non_admin_user = insert(:user)
      token = insert(:oauth_token, user: non_admin_user)

      conn =
        build_conn()
        |> assign(:user, non_admin_user)
        |> assign(:token, token)
        |> get("/api/pleroma/admin/instance_document/instance-panel")

      assert json_response(conn, :forbidden)
    end

    test "it returns 404 if the instance document with the given name doesn't exist", %{
      conn: conn
    } do
      conn = get(conn, "/api/pleroma/admin/instance_document/1234")

      assert json_response_and_validate_schema(conn, 404)
    end
  end

  describe "PATCH /api/pleroma/admin/instance_document/:name" do
    test "uploads the instance document", %{conn: conn} do
      image = %Plug.Upload{
        content_type: "text/html",
        path: Path.absname("test/fixtures/custom_instance_panel.html"),
        filename: "custom_instance_panel.html"
      }

      conn =
        conn
        |> put_req_header("content-type", "multipart/form-data")
        |> patch("/api/pleroma/admin/instance_document/instance-panel", %{
          "file" => image
        })

      assert %{"url" => url} = json_response_and_validate_schema(conn, 200)
      index = get(build_conn(), url)
      assert html_response(index, 200) == "<h2>Custom instance panel</h2>"
    end
  end

  describe "DELETE /api/pleroma/admin/instance_document/:name" do
    test "deletes the instance document", %{conn: conn} do
      File.mkdir!(@dir <> "/instance/")
      File.write!(@dir <> "/instance/panel.html", "Custom instance panel")

      conn_resp =
        conn
        |> get("/api/pleroma/admin/instance_document/instance-panel")

      assert html_response(conn_resp, 200) == "Custom instance panel"

      conn
      |> delete("/api/pleroma/admin/instance_document/instance-panel")
      |> json_response_and_validate_schema(200)

      conn_resp =
        conn
        |> get("/api/pleroma/admin/instance_document/instance-panel")

      assert content = html_response(conn_resp, 200)
      assert String.contains?(content, @default_instance_panel)
    end
  end
end
