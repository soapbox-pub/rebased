# Pleroma: A lightweight social networking server
# Copyright © 2017-2022 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.AdminAPI.OAuthAppControllerTest do
  use Pleroma.Web.ConnCase, async: true
  use Oban.Testing, repo: Pleroma.Repo

  import Pleroma.Factory

  alias Pleroma.Web.Endpoint

  setup do
    admin = insert(:user, is_admin: true)
    token = insert(:oauth_admin_token, user: admin)

    conn =
      build_conn()
      |> assign(:user, admin)
      |> assign(:token, token)

    {:ok, %{admin: admin, token: token, conn: conn}}
  end

  describe "POST /api/pleroma/admin/oauth_app" do
    test "errors", %{conn: conn} do
      response =
        conn
        |> put_req_header("content-type", "application/json")
        |> post("/api/pleroma/admin/oauth_app", %{})
        |> json_response_and_validate_schema(400)

      assert %{
               "error" => "Missing field: name. Missing field: redirect_uris."
             } = response
    end

    test "success", %{conn: conn} do
      base_url = Endpoint.url()
      app_name = "Trusted app"

      response =
        conn
        |> put_req_header("content-type", "application/json")
        |> post("/api/pleroma/admin/oauth_app", %{
          name: app_name,
          redirect_uris: base_url
        })
        |> json_response_and_validate_schema(200)

      assert %{
               "client_id" => _,
               "client_secret" => _,
               "name" => ^app_name,
               "redirect_uri" => ^base_url,
               "trusted" => false
             } = response
    end

    test "with trusted", %{conn: conn} do
      base_url = Endpoint.url()
      app_name = "Trusted app"

      response =
        conn
        |> put_req_header("content-type", "application/json")
        |> post("/api/pleroma/admin/oauth_app", %{
          name: app_name,
          redirect_uris: base_url,
          trusted: true
        })
        |> json_response_and_validate_schema(200)

      assert %{
               "client_id" => _,
               "client_secret" => _,
               "name" => ^app_name,
               "redirect_uri" => ^base_url,
               "trusted" => true
             } = response
    end
  end

  describe "GET /api/pleroma/admin/oauth_app" do
    setup do
      app = insert(:oauth_app)
      {:ok, app: app}
    end

    test "list", %{conn: conn} do
      response =
        conn
        |> get("/api/pleroma/admin/oauth_app")
        |> json_response_and_validate_schema(200)

      assert %{"apps" => apps, "count" => count, "page_size" => _} = response

      assert length(apps) == count
    end

    test "with page size", %{conn: conn} do
      insert(:oauth_app)
      page_size = 1

      response =
        conn
        |> get("/api/pleroma/admin/oauth_app?page_size=#{page_size}")
        |> json_response_and_validate_schema(200)

      assert %{"apps" => apps, "count" => _, "page_size" => ^page_size} = response

      assert length(apps) == page_size
    end

    test "search by client name", %{conn: conn, app: app} do
      response =
        conn
        |> get("/api/pleroma/admin/oauth_app?name=#{app.client_name}")
        |> json_response_and_validate_schema(200)

      assert %{"apps" => [returned], "count" => _, "page_size" => _} = response

      assert returned["client_id"] == app.client_id
      assert returned["name"] == app.client_name
    end

    test "search by client id", %{conn: conn, app: app} do
      response =
        conn
        |> get("/api/pleroma/admin/oauth_app?client_id=#{app.client_id}")
        |> json_response_and_validate_schema(200)

      assert %{"apps" => [returned], "count" => _, "page_size" => _} = response

      assert returned["client_id"] == app.client_id
      assert returned["name"] == app.client_name
    end

    test "only trusted", %{conn: conn} do
      app = insert(:oauth_app, trusted: true)

      response =
        conn
        |> get("/api/pleroma/admin/oauth_app?trusted=true")
        |> json_response_and_validate_schema(200)

      assert %{"apps" => [returned], "count" => _, "page_size" => _} = response

      assert returned["client_id"] == app.client_id
      assert returned["name"] == app.client_name
    end
  end

  describe "DELETE /api/pleroma/admin/oauth_app/:id" do
    test "with id", %{conn: conn} do
      app = insert(:oauth_app)

      response =
        conn
        |> delete("/api/pleroma/admin/oauth_app/" <> to_string(app.id))
        |> json_response_and_validate_schema(:no_content)

      assert response == ""
    end

    test "with non existance id", %{conn: conn} do
      response =
        conn
        |> delete("/api/pleroma/admin/oauth_app/0")
        |> json_response_and_validate_schema(:bad_request)

      assert response == ""
    end
  end

  describe "PATCH /api/pleroma/admin/oauth_app/:id" do
    test "with id", %{conn: conn} do
      app = insert(:oauth_app)

      name = "another name"
      url = "https://example.com"
      scopes = ["admin"]
      id = app.id
      website = "http://website.com"

      response =
        conn
        |> put_req_header("content-type", "application/json")
        |> patch("/api/pleroma/admin/oauth_app/#{id}", %{
          name: name,
          trusted: true,
          redirect_uris: url,
          scopes: scopes,
          website: website
        })
        |> json_response_and_validate_schema(200)

      assert %{
               "client_id" => _,
               "client_secret" => _,
               "id" => ^id,
               "name" => ^name,
               "redirect_uri" => ^url,
               "trusted" => true,
               "website" => ^website
             } = response
    end

    test "without id", %{conn: conn} do
      response =
        conn
        |> put_req_header("content-type", "application/json")
        |> patch("/api/pleroma/admin/oauth_app/0")
        |> json_response_and_validate_schema(:bad_request)

      assert response == ""
    end
  end
end
