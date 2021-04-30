# Pleroma: A lightweight social networking server
# Copyright © 2017-2021 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.FallbackTest do
  use Pleroma.Web.ConnCase
  import Pleroma.Factory

  describe "neither preloaded data nor metadata attached to" do
    test "GET /registration/:token", %{conn: conn} do
      response = get(conn, "/registration/foo")

      assert html_response(response, 200) =~ "<!--server-generated-meta-->"
    end

    test "GET /*path", %{conn: conn} do
      assert conn
             |> get("/foo")
             |> html_response(200) =~ "<!--server-generated-meta-->"
    end
  end

  test "GET /*path adds a title", %{conn: conn} do
    clear_config([:instance, :name], "a cool title")

    assert conn
           |> get("/")
           |> html_response(200) =~ "<title>a cool title</title>"
  end

  describe "preloaded data and metadata attached to" do
    test "GET /:maybe_nickname_or_id", %{conn: conn} do
      clear_config([:instance, :name], "a cool title")

      user = insert(:user)
      user_missing = get(conn, "/foo")
      user_present = get(conn, "/#{user.nickname}")

      assert html_response(user_missing, 200) =~ "<!--server-generated-meta-->"
      refute html_response(user_present, 200) =~ "<!--server-generated-meta-->"
      assert html_response(user_present, 200) =~ "initial-results"
      assert html_response(user_present, 200) =~ "<title>a cool title</title>"
    end

    test "GET /*path", %{conn: conn} do
      assert conn
             |> get("/foo")
             |> html_response(200) =~ "<!--server-generated-meta-->"

      refute conn
             |> get("/foo/bar")
             |> html_response(200) =~ "<!--server-generated-meta-->"
    end
  end

  describe "preloaded data is attached to" do
    test "GET /main/public", %{conn: conn} do
      clear_config([:instance, :name], "a cool title")

      public_page = get(conn, "/main/public")

      refute html_response(public_page, 200) =~ "<!--server-generated-meta-->"
      assert html_response(public_page, 200) =~ "initial-results"
      assert html_response(public_page, 200) =~ "<title>a cool title</title>"
    end

    test "GET /main/all", %{conn: conn} do
      public_page = get(conn, "/main/all")

      refute html_response(public_page, 200) =~ "<!--server-generated-meta-->"
      assert html_response(public_page, 200) =~ "initial-results"
    end
  end

  test "GET /api*path", %{conn: conn} do
    assert conn
           |> get("/api/foo")
           |> json_response(404) == %{"error" => "Not implemented"}
  end

  test "GET /pleroma/admin -> /pleroma/admin/", %{conn: conn} do
    assert redirected_to(get(conn, "/pleroma/admin")) =~ "/pleroma/admin/"
  end

  test "OPTIONS /*path", %{conn: conn} do
    assert conn
           |> options("/foo")
           |> response(204) == ""

    assert conn
           |> options("/foo/bar")
           |> response(204) == ""
  end
end
