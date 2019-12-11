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
        {Pleroma.Activity, [], [search: fn _u, _q, _o -> raise "Oops" end]}
      ] do
        capture_log(fn ->
          results =
            conn
            |> get("/api/v2/search", %{"q" => "2hu"})
            |> json_response(200)

          assert results["accounts"] == []
          assert results["statuses"] == []
        end) =~
          "[error] Elixir.Pleroma.Web.MastodonAPI.SearchController search error: %RuntimeError{message: \"Oops\"}"
      end
    end

    test "search", %{conn: conn} do
      user = insert(:user)
      user_two = insert(:user, %{nickname: "shp@shitposter.club"})
      user_three = insert(:user, %{nickname: "shp@heldscal.la", name: "I love 2hu"})

      {:ok, activity} = CommonAPI.post(user, %{"status" => "This is about 2hu private 天子"})

      {:ok, _activity} =
        CommonAPI.post(user, %{
          "status" => "This is about 2hu, but private",
          "visibility" => "private"
        })

      {:ok, _} = CommonAPI.post(user_two, %{"status" => "This isn't"})

      results =
        get(conn, "/api/v2/search", %{"q" => "2hu #private"})
        |> json_response(200)

      [account | _] = results["accounts"]
      assert account["id"] == to_string(user_three.id)

      assert results["hashtags"] == [
               %{"name" => "private", "url" => "#{Web.base_url()}/tag/private"}
             ]

      [status] = results["statuses"]
      assert status["id"] == to_string(activity.id)

      results =
        get(conn, "/api/v2/search", %{"q" => "天子"})
        |> json_response(200)

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

    test "returns account if query contains a space", %{conn: conn} do
      user = insert(:user, %{nickname: "shp@shitposter.club"})

      results =
        conn
        |> assign(:user, user)
        |> get("/api/v1/accounts/search", %{"q" => "shp@shitposter.club xxx "})
        |> json_response(200)

      assert length(results) == 1
    end
  end

  describe ".search" do
    test "it returns empty result if user or status search return undefined error", %{conn: conn} do
      with_mocks [
        {Pleroma.User, [], [search: fn _q, _o -> raise "Oops" end]},
        {Pleroma.Activity, [], [search: fn _u, _q, _o -> raise "Oops" end]}
      ] do
        capture_log(fn ->
          results =
            conn
            |> get("/api/v1/search", %{"q" => "2hu"})
            |> json_response(200)

          assert results["accounts"] == []
          assert results["statuses"] == []
        end) =~
          "[error] Elixir.Pleroma.Web.MastodonAPI.SearchController search error: %RuntimeError{message: \"Oops\"}"
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

    test "search fetches remote statuses and prefers them over other results", %{conn: conn} do
      capture_log(fn ->
        {:ok, %{id: activity_id}} =
          CommonAPI.post(insert(:user), %{
            "status" => "check out https://shitposter.club/notice/2827873"
          })

        conn =
          conn
          |> get("/api/v1/search", %{"q" => "https://shitposter.club/notice/2827873"})

        assert results = json_response(conn, 200)

        [status, %{"id" => ^activity_id}] = results["statuses"]

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
        |> get("/api/v1/search", %{"q" => "mike@osada.macgirvin.com", "resolve" => "true"})

      assert results = json_response(conn, 200)
      [account] = results["accounts"]
      assert account["acct"] == "mike@osada.macgirvin.com"
    end

    test "search doesn't fetch remote accounts if resolve is false", %{conn: conn} do
      conn =
        conn
        |> get("/api/v1/search", %{"q" => "mike@osada.macgirvin.com", "resolve" => "false"})

      assert results = json_response(conn, 200)
      assert [] == results["accounts"]
    end

    test "search with limit and offset", %{conn: conn} do
      user = insert(:user)
      _user_two = insert(:user, %{nickname: "shp@shitposter.club"})
      _user_three = insert(:user, %{nickname: "shp@heldscal.la", name: "I love 2hu"})

      {:ok, _activity1} = CommonAPI.post(user, %{"status" => "This is about 2hu"})
      {:ok, _activity2} = CommonAPI.post(user, %{"status" => "This is also about 2hu"})

      result =
        conn
        |> get("/api/v1/search", %{"q" => "2hu", "limit" => 1})

      assert results = json_response(result, 200)
      assert [%{"id" => activity_id1}] = results["statuses"]
      assert [_] = results["accounts"]

      results =
        conn
        |> get("/api/v1/search", %{"q" => "2hu", "limit" => 1, "offset" => 1})
        |> json_response(200)

      assert [%{"id" => activity_id2}] = results["statuses"]
      assert [] = results["accounts"]

      assert activity_id1 != activity_id2
    end

    test "search returns results only for the given type", %{conn: conn} do
      user = insert(:user)
      _user_two = insert(:user, %{nickname: "shp@heldscal.la", name: "I love 2hu"})

      {:ok, _activity} = CommonAPI.post(user, %{"status" => "This is about 2hu"})

      assert %{"statuses" => [_activity], "accounts" => [], "hashtags" => []} =
               conn
               |> get("/api/v1/search", %{"q" => "2hu", "type" => "statuses"})
               |> json_response(200)

      assert %{"statuses" => [], "accounts" => [_user_two], "hashtags" => []} =
               conn
               |> get("/api/v1/search", %{"q" => "2hu", "type" => "accounts"})
               |> json_response(200)
    end

    test "search uses account_id to filter statuses by the author", %{conn: conn} do
      user = insert(:user, %{nickname: "shp@shitposter.club"})
      user_two = insert(:user, %{nickname: "shp@heldscal.la", name: "I love 2hu"})

      {:ok, activity1} = CommonAPI.post(user, %{"status" => "This is about 2hu"})
      {:ok, activity2} = CommonAPI.post(user_two, %{"status" => "This is also about 2hu"})

      results =
        conn
        |> get("/api/v1/search", %{"q" => "2hu", "account_id" => user.id})
        |> json_response(200)

      assert [%{"id" => activity_id1}] = results["statuses"]
      assert activity_id1 == activity1.id
      assert [_] = results["accounts"]

      results =
        conn
        |> get("/api/v1/search", %{"q" => "2hu", "account_id" => user_two.id})
        |> json_response(200)

      assert [%{"id" => activity_id2}] = results["statuses"]
      assert activity_id2 == activity2.id
    end
  end
end
