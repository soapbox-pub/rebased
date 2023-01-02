# Pleroma: A lightweight social networking server
# Copyright © 2017-2022 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.AdminAPI.FrontendControllerTest do
  use Pleroma.Web.ConnCase

  import Pleroma.Factory

  alias Pleroma.Config

  @dir "test/frontend_static_test"

  setup do
    clear_config([:instance, :static_dir], @dir)
    File.mkdir_p!(Pleroma.Frontend.dir())

    on_exit(fn ->
      File.rm_rf(@dir)
    end)

    admin = insert(:user, is_admin: true)
    token = insert(:oauth_admin_token, user: admin)

    conn =
      build_conn()
      |> assign(:user, admin)
      |> assign(:token, token)

    {:ok, %{admin: admin, token: token, conn: conn}}
  end

  describe "GET /api/pleroma/admin/frontends" do
    test "it lists available frontends", %{conn: conn} do
      response =
        conn
        |> get("/api/pleroma/admin/frontends")
        |> json_response_and_validate_schema(:ok)

      assert Enum.map(response, & &1["name"]) ==
               Enum.map(Config.get([:frontends, :available]), fn {_, map} -> map["name"] end)

      refute Enum.any?(response, fn frontend -> frontend["installed"] == true end)
    end

    test "it lists available frontends when no frontend folder was created yet", %{conn: conn} do
      File.rm_rf(@dir)

      response =
        conn
        |> get("/api/pleroma/admin/frontends")
        |> json_response_and_validate_schema(:ok)

      assert Enum.map(response, & &1["name"]) ==
               Enum.map(Config.get([:frontends, :available]), fn {_, map} -> map["name"] end)

      refute Enum.any?(response, fn frontend -> frontend["installed"] == true end)
    end
  end

  describe "POST /api/pleroma/admin/frontends/install" do
    test "from available frontends", %{conn: conn} do
      clear_config([:frontends, :available], %{
        "pleroma" => %{
          "ref" => "fantasy",
          "name" => "pleroma",
          "build_url" => "http://gensokyo.2hu/builds/${ref}"
        }
      })

      Tesla.Mock.mock(fn %{url: "http://gensokyo.2hu/builds/fantasy"} ->
        %Tesla.Env{status: 200, body: File.read!("test/fixtures/tesla_mock/frontend_dist.zip")}
      end)

      conn
      |> put_req_header("content-type", "application/json")
      |> post("/api/pleroma/admin/frontends/install", %{name: "pleroma"})
      |> json_response_and_validate_schema(:ok)

      assert File.exists?(Path.join([@dir, "frontends", "pleroma", "fantasy", "test.txt"]))

      response =
        conn
        |> get("/api/pleroma/admin/frontends")
        |> json_response_and_validate_schema(:ok)

      assert response == [
               %{
                 "build_url" => "http://gensokyo.2hu/builds/${ref}",
                 "git" => nil,
                 "installed" => true,
                 "name" => "pleroma",
                 "ref" => "fantasy"
               }
             ]
    end

    test "from a file", %{conn: conn} do
      clear_config([:frontends, :available], %{
        "pleroma" => %{
          "ref" => "fantasy",
          "name" => "pleroma",
          "build_dir" => ""
        }
      })

      conn
      |> put_req_header("content-type", "application/json")
      |> post("/api/pleroma/admin/frontends/install", %{
        name: "pleroma",
        file: "test/fixtures/tesla_mock/frontend.zip"
      })
      |> json_response_and_validate_schema(:ok)

      assert File.exists?(Path.join([@dir, "frontends", "pleroma", "fantasy", "test.txt"]))
    end

    test "from an URL", %{conn: conn} do
      Tesla.Mock.mock(fn %{url: "http://gensokyo.2hu/madeup.zip"} ->
        %Tesla.Env{status: 200, body: File.read!("test/fixtures/tesla_mock/frontend.zip")}
      end)

      conn
      |> put_req_header("content-type", "application/json")
      |> post("/api/pleroma/admin/frontends/install", %{
        name: "unknown",
        ref: "baka",
        build_url: "http://gensokyo.2hu/madeup.zip",
        build_dir: ""
      })
      |> json_response_and_validate_schema(:ok)

      assert File.exists?(Path.join([@dir, "frontends", "unknown", "baka", "test.txt"]))
    end

    test "failing returns an error", %{conn: conn} do
      Tesla.Mock.mock(fn %{url: "http://gensokyo.2hu/madeup.zip"} ->
        %Tesla.Env{status: 404, body: ""}
      end)

      result =
        conn
        |> put_req_header("content-type", "application/json")
        |> post("/api/pleroma/admin/frontends/install", %{
          name: "unknown",
          ref: "baka",
          build_url: "http://gensokyo.2hu/madeup.zip",
          build_dir: ""
        })
        |> json_response_and_validate_schema(400)

      assert result == %{"error" => "Could not download or unzip the frontend"}
    end
  end
end
