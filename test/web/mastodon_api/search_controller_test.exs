# Pleroma: A lightweight social networking server
# Copyright © 2017-2019 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.MastodonAPI.SearchControllerTest do
  use Pleroma.Web.ConnCase

  alias Pleroma.Object
  alias Pleroma.Web
  alias Pleroma.Web.CommonAPI
  import Pleroma.Factory
  import ExUnit.CaptureLog
  import Tesla.Mock
  import Mock

  setup do
    mock_global(fn env -> apply(HttpRequestMock, :request, [env]) end)
    :ok
  end

  describe ".search2" do
    test "it returns empty result if user or status search return undefined error", %{conn: conn} do
      with_mocks [
        {Pleroma.User, [], [search: fn _q, _o -> raise "Oops" end]},
        {Pleroma.Activity, [], [search: fn _u, _q -> raise "Oops" end]}
      ] do
        conn = get(conn, "/api/v2/search", %{"q" => "2hu"})

        assert results = json_response(conn, 200)

        assert results["accounts"] == []
        assert results["statuses"] == []
      end
    end

    test "search", %{conn: conn} do
      user = insert(:user)
      user_two = insert(:user, %{nickname: "shp@shitposter.club"})
      user_three = insert(:user, %{nickname: "shp@heldscal.la", name: "I love 2hu"})

      {:ok, activity} = CommonAPI.post(user, %{"status" => "This is about 2hu private"})

      {:ok, _activity} =
        CommonAPI.post(user, %{
          "status" => "This is about 2hu, but private",
          "visibility" => "private"
        })

      {:ok, _} = CommonAPI.post(user_two, %{"status" => "This isn't"})

      conn = get(conn, "/api/v2/search", %{"q" => "2hu #private"})

      assert results = json_response(conn, 200)
      # IO.inspect results

      [account | _] = results["accounts"]
      assert account["id"] == to_string(user_three.id)

      assert results["hashtags"] == [
               %{"name" => "private", "url" => "#{Web.base_url()}/tag/private"}
             ]

      [status] = results["statuses"]
      assert status["id"] == to_string(activity.id)
    end
  end

  describe ".account_search" do
    test "account search", %{conn: conn} do
      user = insert(:user)
      user_two = insert(:user, %{nickname: "shp@shitposter.club"})
      user_three = insert(:user, %{nickname: "shp@heldscal.la", name: "I love 2hu"})

      results =
        conn
        |> assign(:user, user)
        |> get("/api/v1/accounts/search", %{"q" => "shp"})
        |> json_response(200)

      result_ids = for result <- results, do: result["acct"]

      assert user_two.nickname in result_ids
      assert user_three.nickname in result_ids

      results =
        conn
        |> assign(:user, user)
        |> get("/api/v1/accounts/search", %{"q" => "2hu"})
        |> json_response(200)

      result_ids = for result <- results, do: result["acct"]

      assert user_three.nickname in result_ids
    end
  end

  describe ".search" do
    test "it returns empty result if user or status search return undefined error", %{conn: conn} do
      with_mocks [
        {Pleroma.User, [], [search: fn _q, _o -> raise "Oops" end]},
        {Pleroma.Activity, [], [search: fn _u, _q -> raise "Oops" end]}
      ] do
        conn =
          conn
          |> get("/api/v1/search", %{"q" => "2hu"})

        assert results = json_response(conn, 200)

        assert results["accounts"] == []
        assert results["statuses"] == []
      end
    end

    test "search", %{conn: conn} do
      user = insert(:user)
      user_two = insert(:user, %{nickname: "shp@shitposter.club"})
      user_three = insert(:user, %{nickname: "shp@heldscal.la", name: "I love 2hu"})

      {:ok, activity} = CommonAPI.post(user, %{"status" => "This is about 2hu"})

      {:ok, _activity} =
        CommonAPI.post(user, %{
          "status" => "This is about 2hu, but private",
          "visibility" => "private"
        })

      {:ok, _} = CommonAPI.post(user_two, %{"status" => "This isn't"})

      conn =
        conn
        |> get("/api/v1/search", %{"q" => "2hu"})

      assert results = json_response(conn, 200)

      [account | _] = results["accounts"]
      assert account["id"] == to_string(user_three.id)

      assert results["hashtags"] == []

      [status] = results["statuses"]
      assert status["id"] == to_string(activity.id)
    end

    test "search fetches remote statuses", %{conn: conn} do
      capture_log(fn ->
        conn =
          conn
          |> get("/api/v1/search", %{"q" => "https://shitposter.club/notice/2827873"})

        assert results = json_response(conn, 200)

        [status] = results["statuses"]

        assert status["uri"] ==
                 "tag:shitposter.club,2017-05-05:noticeId=2827873:objectType=comment"
      end)
    end

    test "search doesn't show statuses that it shouldn't", %{conn: conn} do
      {:ok, activity} =
        CommonAPI.post(insert(:user), %{
          "status" => "This is about 2hu, but private",
          "visibility" => "private"
        })

      capture_log(fn ->
        conn =
          conn
          |> get("/api/v1/search", %{"q" => Object.normalize(activity).data["id"]})

        assert results = json_response(conn, 200)

        [] = results["statuses"]
      end)
    end

    test "search fetches remote accounts", %{conn: conn} do
      user = insert(:user)

      conn =
        conn
        |> assign(:user, user)
        |> get("/api/v1/search", %{"q" => "shp@social.heldscal.la", "resolve" => "true"})

      assert results = json_response(conn, 200)
      [account] = results["accounts"]
      assert account["acct"] == "shp@social.heldscal.la"
    end

    test "search doesn't fetch remote accounts if resolve is false", %{conn: conn} do
      conn =
        conn
        |> get("/api/v1/search", %{"q" => "shp@social.heldscal.la", "resolve" => "false"})

      assert results = json_response(conn, 200)
      assert [] == results["accounts"]
    end
  end
end
