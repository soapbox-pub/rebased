# Pleroma: A lightweight social networking server
# Copyright © 2017-2022 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.Auth.AuthControllerTest do
  use Pleroma.Web.ConnCase

  import Pleroma.Factory

  describe "do_oauth_check" do
    test "serves with proper OAuth token (fulfilling requested scopes)" do
      %{conn: good_token_conn, user: user} = oauth_access(["read"])

      assert %{"user_id" => user.id} ==
               good_token_conn
               |> get("/test/authenticated_api/do_oauth_check")
               |> json_response(200)

      # Unintended usage (:api) — use with :authenticated_api instead
      assert %{"user_id" => user.id} ==
               good_token_conn
               |> get("/test/api/do_oauth_check")
               |> json_response(200)
    end

    test "fails on no token / missing scope(s)" do
      %{conn: bad_token_conn} = oauth_access(["irrelevant_scope"])

      bad_token_conn
      |> get("/test/authenticated_api/do_oauth_check")
      |> json_response(403)

      bad_token_conn
      |> assign(:token, nil)
      |> get("/test/api/do_oauth_check")
      |> json_response(403)
    end
  end

  describe "fallback_oauth_check" do
    test "serves with proper OAuth token (fulfilling requested scopes)" do
      %{conn: good_token_conn, user: user} = oauth_access(["read"])

      assert %{"user_id" => user.id} ==
               good_token_conn
               |> get("/test/api/fallback_oauth_check")
               |> json_response(200)

      # Unintended usage (:authenticated_api) — use with :api instead
      assert %{"user_id" => user.id} ==
               good_token_conn
               |> get("/test/authenticated_api/fallback_oauth_check")
               |> json_response(200)
    end

    test "for :api on public instance, drops :user and renders on no token / missing scope(s)" do
      clear_config([:instance, :public], true)

      %{conn: bad_token_conn} = oauth_access(["irrelevant_scope"])

      assert %{"user_id" => nil} ==
               bad_token_conn
               |> get("/test/api/fallback_oauth_check")
               |> json_response(200)

      assert %{"user_id" => nil} ==
               bad_token_conn
               |> assign(:token, nil)
               |> get("/test/api/fallback_oauth_check")
               |> json_response(200)
    end

    test "for :api on private instance, fails on no token / missing scope(s)" do
      clear_config([:instance, :public], false)

      %{conn: bad_token_conn} = oauth_access(["irrelevant_scope"])

      bad_token_conn
      |> get("/test/api/fallback_oauth_check")
      |> json_response(403)

      bad_token_conn
      |> assign(:token, nil)
      |> get("/test/api/fallback_oauth_check")
      |> json_response(403)
    end
  end

  describe "skip_oauth_check" do
    test "for :authenticated_api, serves if :user is set (regardless of token / token scopes)" do
      user = insert(:user)

      assert %{"user_id" => user.id} ==
               build_conn()
               |> assign(:user, user)
               |> get("/test/authenticated_api/skip_oauth_check")
               |> json_response(200)

      %{conn: bad_token_conn, user: user} = oauth_access(["irrelevant_scope"])

      assert %{"user_id" => user.id} ==
               bad_token_conn
               |> get("/test/authenticated_api/skip_oauth_check")
               |> json_response(200)
    end

    test "serves via :api on public instance if :user is not set" do
      clear_config([:instance, :public], true)

      assert %{"user_id" => nil} ==
               build_conn()
               |> get("/test/api/skip_oauth_check")
               |> json_response(200)

      build_conn()
      |> get("/test/authenticated_api/skip_oauth_check")
      |> json_response(403)
    end

    test "fails on private instance if :user is not set" do
      clear_config([:instance, :public], false)

      build_conn()
      |> get("/test/api/skip_oauth_check")
      |> json_response(403)

      build_conn()
      |> get("/test/authenticated_api/skip_oauth_check")
      |> json_response(403)
    end
  end

  describe "fallback_oauth_skip_publicity_check" do
    test "serves with proper OAuth token (fulfilling requested scopes)" do
      %{conn: good_token_conn, user: user} = oauth_access(["read"])

      assert %{"user_id" => user.id} ==
               good_token_conn
               |> get("/test/api/fallback_oauth_skip_publicity_check")
               |> json_response(200)

      # Unintended usage (:authenticated_api)
      assert %{"user_id" => user.id} ==
               good_token_conn
               |> get("/test/authenticated_api/fallback_oauth_skip_publicity_check")
               |> json_response(200)
    end

    test "for :api on private / public instance, drops :user and renders on token issue" do
      %{conn: bad_token_conn} = oauth_access(["irrelevant_scope"])

      for is_public <- [true, false] do
        clear_config([:instance, :public], is_public)

        assert %{"user_id" => nil} ==
                 bad_token_conn
                 |> get("/test/api/fallback_oauth_skip_publicity_check")
                 |> json_response(200)

        assert %{"user_id" => nil} ==
                 bad_token_conn
                 |> assign(:token, nil)
                 |> get("/test/api/fallback_oauth_skip_publicity_check")
                 |> json_response(200)
      end
    end
  end

  describe "skip_oauth_skip_publicity_check" do
    test "for :authenticated_api, serves if :user is set (regardless of token / token scopes)" do
      user = insert(:user)

      assert %{"user_id" => user.id} ==
               build_conn()
               |> assign(:user, user)
               |> get("/test/authenticated_api/skip_oauth_skip_publicity_check")
               |> json_response(200)

      %{conn: bad_token_conn, user: user} = oauth_access(["irrelevant_scope"])

      assert %{"user_id" => user.id} ==
               bad_token_conn
               |> get("/test/authenticated_api/skip_oauth_skip_publicity_check")
               |> json_response(200)
    end

    test "for :api, serves on private and public instances regardless of whether :user is set" do
      user = insert(:user)

      for is_public <- [true, false] do
        clear_config([:instance, :public], is_public)

        assert %{"user_id" => nil} ==
                 build_conn()
                 |> get("/test/api/skip_oauth_skip_publicity_check")
                 |> json_response(200)

        assert %{"user_id" => user.id} ==
                 build_conn()
                 |> assign(:user, user)
                 |> get("/test/api/skip_oauth_skip_publicity_check")
                 |> json_response(200)
      end
    end
  end

  describe "missing_oauth_check_definition" do
    def test_missing_oauth_check_definition_failure(endpoint, expected_error) do
      %{conn: conn} = oauth_access(["read", "write", "follow", "push", "admin"])

      assert %{"error" => expected_error} ==
               conn
               |> get(endpoint)
               |> json_response(403)
    end

    test "fails if served via :authenticated_api" do
      test_missing_oauth_check_definition_failure(
        "/test/authenticated_api/missing_oauth_check_definition",
        "Security violation: OAuth scopes check was neither handled nor explicitly skipped."
      )
    end

    test "fails if served via :api and the instance is private" do
      clear_config([:instance, :public], false)

      test_missing_oauth_check_definition_failure(
        "/test/api/missing_oauth_check_definition",
        "This resource requires authentication."
      )
    end

    test "succeeds with dropped :user if served via :api on public instance" do
      %{conn: conn} = oauth_access(["read", "write", "follow", "push", "admin"])

      assert %{"user_id" => nil} ==
               conn
               |> get("/test/api/missing_oauth_check_definition")
               |> json_response(200)
    end
  end
end
