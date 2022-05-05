# Pleroma: A lightweight social networking server
# Copyright © 2017-2022 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.MastodonAPI.SearchControllerTest do
  use Pleroma.Web.ConnCase

  alias Pleroma.Object
  alias Pleroma.Web.CommonAPI
  alias Pleroma.Web.Endpoint
  import Pleroma.Factory
  import ExUnit.CaptureLog
  import Tesla.Mock
  import Mock

  setup_all do
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
            |> get("/api/v2/search?q=2hu")
            |> json_response_and_validate_schema(200)

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

      {:ok, activity} = CommonAPI.post(user, %{status: "This is about 2hu private 天子"})

      {:ok, _activity} =
        CommonAPI.post(user, %{
          status: "This is about 2hu, but private",
          visibility: "private"
        })

      {:ok, _} = CommonAPI.post(user_two, %{status: "This isn't"})

      results =
        conn
        |> get("/api/v2/search?#{URI.encode_query(%{q: "2hu #private"})}")
        |> json_response_and_validate_schema(200)

      [account | _] = results["accounts"]
      assert account["id"] == to_string(user_three.id)

      assert results["hashtags"] == [
               %{"name" => "private", "url" => "#{Endpoint.url()}/tag/private"}
             ]

      [status] = results["statuses"]
      assert status["id"] == to_string(activity.id)

      results =
        get(conn, "/api/v2/search?q=天子")
        |> json_response_and_validate_schema(200)

      assert results["hashtags"] == [
               %{"name" => "天子", "url" => "#{Endpoint.url()}/tag/天子"}
             ]

      [status] = results["statuses"]
      assert status["id"] == to_string(activity.id)
    end

    test "search local-only status as an authenticated user" do
      user = insert(:user)
      %{conn: conn} = oauth_access(["read:search"])

      {:ok, activity} =
        CommonAPI.post(user, %{status: "This is about 2hu private 天子", visibility: "local"})

      results =
        conn
        |> get("/api/v2/search?#{URI.encode_query(%{q: "2hu"})}")
        |> json_response_and_validate_schema(200)

      [status] = results["statuses"]
      assert status["id"] == to_string(activity.id)
    end

    test "search local-only status as an unauthenticated user" do
      user = insert(:user)
      %{conn: conn} = oauth_access([])

      {:ok, _activity} =
        CommonAPI.post(user, %{status: "This is about 2hu private 天子", visibility: "local"})

      results =
        conn
        |> get("/api/v2/search?#{URI.encode_query(%{q: "2hu"})}")
        |> json_response_and_validate_schema(200)

      assert [] = results["statuses"]
    end

    test "search local-only status as an anonymous user" do
      user = insert(:user)

      {:ok, _activity} =
        CommonAPI.post(user, %{status: "This is about 2hu private 天子", visibility: "local"})

      results =
        build_conn()
        |> get("/api/v2/search?#{URI.encode_query(%{q: "2hu"})}")
        |> json_response_and_validate_schema(200)

      assert [] = results["statuses"]
    end

    @tag capture_log: true
    test "constructs hashtags from search query", %{conn: conn} do
      results =
        conn
        |> get("/api/v2/search?#{URI.encode_query(%{q: "some text with #explicit #hashtags"})}")
        |> json_response_and_validate_schema(200)

      assert results["hashtags"] == [
               %{"name" => "explicit", "url" => "#{Endpoint.url()}/tag/explicit"},
               %{"name" => "hashtags", "url" => "#{Endpoint.url()}/tag/hashtags"}
             ]

      results =
        conn
        |> get("/api/v2/search?#{URI.encode_query(%{q: "john doe JOHN DOE"})}")
        |> json_response_and_validate_schema(200)

      assert results["hashtags"] == [
               %{"name" => "john", "url" => "#{Endpoint.url()}/tag/john"},
               %{"name" => "doe", "url" => "#{Endpoint.url()}/tag/doe"},
               %{"name" => "JohnDoe", "url" => "#{Endpoint.url()}/tag/JohnDoe"}
             ]

      results =
        conn
        |> get("/api/v2/search?#{URI.encode_query(%{q: "accident-prone"})}")
        |> json_response_and_validate_schema(200)

      assert results["hashtags"] == [
               %{"name" => "accident", "url" => "#{Endpoint.url()}/tag/accident"},
               %{"name" => "prone", "url" => "#{Endpoint.url()}/tag/prone"},
               %{"name" => "AccidentProne", "url" => "#{Endpoint.url()}/tag/AccidentProne"}
             ]

      results =
        conn
        |> get("/api/v2/search?#{URI.encode_query(%{q: "https://shpposter.club/users/shpuld"})}")
        |> json_response_and_validate_schema(200)

      assert results["hashtags"] == [
               %{"name" => "shpuld", "url" => "#{Endpoint.url()}/tag/shpuld"}
             ]

      results =
        conn
        |> get(
          "/api/v2/search?#{URI.encode_query(%{q: "https://www.washingtonpost.com/sports/2020/06/10/" <> "nascar-ban-display-confederate-flag-all-events-properties/"})}"
        )
        |> json_response_and_validate_schema(200)

      assert results["hashtags"] == [
               %{"name" => "nascar", "url" => "#{Endpoint.url()}/tag/nascar"},
               %{"name" => "ban", "url" => "#{Endpoint.url()}/tag/ban"},
               %{"name" => "display", "url" => "#{Endpoint.url()}/tag/display"},
               %{"name" => "confederate", "url" => "#{Endpoint.url()}/tag/confederate"},
               %{"name" => "flag", "url" => "#{Endpoint.url()}/tag/flag"},
               %{"name" => "all", "url" => "#{Endpoint.url()}/tag/all"},
               %{"name" => "events", "url" => "#{Endpoint.url()}/tag/events"},
               %{"name" => "properties", "url" => "#{Endpoint.url()}/tag/properties"},
               %{
                 "name" => "NascarBanDisplayConfederateFlagAllEventsProperties",
                 "url" =>
                   "#{Endpoint.url()}/tag/NascarBanDisplayConfederateFlagAllEventsProperties"
               }
             ]
    end

    test "supports pagination of hashtags search results", %{conn: conn} do
      results =
        conn
        |> get(
          "/api/v2/search?#{URI.encode_query(%{q: "#some #text #with #hashtags", limit: 2, offset: 1})}"
        )
        |> json_response_and_validate_schema(200)

      assert results["hashtags"] == [
               %{"name" => "text", "url" => "#{Endpoint.url()}/tag/text"},
               %{"name" => "with", "url" => "#{Endpoint.url()}/tag/with"}
             ]
    end

    test "excludes a blocked users from search results", %{conn: conn} do
      user = insert(:user)
      user_smith = insert(:user, %{nickname: "Agent", name: "I love 2hu"})
      user_neo = insert(:user, %{nickname: "Agent Neo", name: "Agent"})

      {:ok, act1} = CommonAPI.post(user, %{status: "This is about 2hu private 天子"})
      {:ok, act2} = CommonAPI.post(user_smith, %{status: "Agent Smith"})
      {:ok, act3} = CommonAPI.post(user_neo, %{status: "Agent Smith"})
      Pleroma.User.block(user, user_smith)

      results =
        conn
        |> assign(:user, user)
        |> assign(:token, insert(:oauth_token, user: user, scopes: ["read"]))
        |> get("/api/v2/search?q=Agent")
        |> json_response_and_validate_schema(200)

      status_ids = Enum.map(results["statuses"], fn g -> g["id"] end)

      assert act3.id in status_ids
      refute act2.id in status_ids
      refute act1.id in status_ids
    end
  end

  describe ".account_search" do
    test "account search", %{conn: conn} do
      user_two = insert(:user, %{nickname: "shp@shitposter.club"})
      user_three = insert(:user, %{nickname: "shp@heldscal.la", name: "I love 2hu"})

      results =
        conn
        |> get("/api/v1/accounts/search?q=shp")
        |> json_response_and_validate_schema(200)

      result_ids = for result <- results, do: result["acct"]

      assert user_two.nickname in result_ids
      assert user_three.nickname in result_ids

      results =
        conn
        |> get("/api/v1/accounts/search?q=2hu")
        |> json_response_and_validate_schema(200)

      result_ids = for result <- results, do: result["acct"]

      assert user_three.nickname in result_ids
    end

    test "returns account if query contains a space", %{conn: conn} do
      insert(:user, %{nickname: "shp@shitposter.club"})

      results =
        conn
        |> get("/api/v1/accounts/search?q=shp@shitposter.club xxx")
        |> json_response_and_validate_schema(200)

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
            |> get("/api/v1/search?q=2hu")
            |> json_response_and_validate_schema(200)

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

      {:ok, activity} = CommonAPI.post(user, %{status: "This is about 2hu"})

      {:ok, _activity} =
        CommonAPI.post(user, %{
          status: "This is about 2hu, but private",
          visibility: "private"
        })

      {:ok, _} = CommonAPI.post(user_two, %{status: "This isn't"})

      results =
        conn
        |> get("/api/v1/search?q=2hu")
        |> json_response_and_validate_schema(200)

      [account | _] = results["accounts"]
      assert account["id"] == to_string(user_three.id)

      assert results["hashtags"] == ["2hu"]

      [status] = results["statuses"]
      assert status["id"] == to_string(activity.id)
    end

    test "search fetches remote statuses and prefers them over other results", %{conn: conn} do
      old_version = :persistent_term.get({Pleroma.Repo, :postgres_version})
      :persistent_term.put({Pleroma.Repo, :postgres_version}, 10.0)
      on_exit(fn -> :persistent_term.put({Pleroma.Repo, :postgres_version}, old_version) end)

      capture_log(fn ->
        {:ok, %{id: activity_id}} =
          CommonAPI.post(insert(:user), %{
            status: "check out http://mastodon.example.org/@admin/99541947525187367"
          })

        results =
          conn
          |> get("/api/v1/search?q=http://mastodon.example.org/@admin/99541947525187367")
          |> json_response_and_validate_schema(200)

        assert [
                 %{"url" => "http://mastodon.example.org/@admin/99541947525187367"},
                 %{"id" => ^activity_id}
               ] = results["statuses"]
      end)
    end

    test "search doesn't show statuses that it shouldn't", %{conn: conn} do
      {:ok, activity} =
        CommonAPI.post(insert(:user), %{
          status: "This is about 2hu, but private",
          visibility: "private"
        })

      capture_log(fn ->
        q = Object.normalize(activity, fetch: false).data["id"]

        results =
          conn
          |> get("/api/v1/search?q=#{q}")
          |> json_response_and_validate_schema(200)

        [] = results["statuses"]
      end)
    end

    test "search fetches remote accounts", %{conn: conn} do
      user = insert(:user)

      query = URI.encode_query(%{q: "       mike@osada.macgirvin.com          ", resolve: true})

      results =
        conn
        |> assign(:user, user)
        |> assign(:token, insert(:oauth_token, user: user, scopes: ["read"]))
        |> get("/api/v1/search?#{query}")
        |> json_response_and_validate_schema(200)

      [account] = results["accounts"]
      assert account["acct"] == "mike@osada.macgirvin.com"
    end

    test "search doesn't fetch remote accounts if resolve is false", %{conn: conn} do
      results =
        conn
        |> get("/api/v1/search?q=mike@osada.macgirvin.com&resolve=false")
        |> json_response_and_validate_schema(200)

      assert [] == results["accounts"]
    end

    test "search with limit and offset", %{conn: conn} do
      user = insert(:user)
      _user_two = insert(:user, %{nickname: "shp@shitposter.club"})
      _user_three = insert(:user, %{nickname: "shp@heldscal.la", name: "I love 2hu"})

      {:ok, _activity1} = CommonAPI.post(user, %{status: "This is about 2hu"})
      {:ok, _activity2} = CommonAPI.post(user, %{status: "This is also about 2hu"})

      result =
        conn
        |> get("/api/v1/search?q=2hu&limit=1")

      assert results = json_response_and_validate_schema(result, 200)
      assert [%{"id" => activity_id1}] = results["statuses"]
      assert [_] = results["accounts"]

      results =
        conn
        |> get("/api/v1/search?q=2hu&limit=1&offset=1")
        |> json_response_and_validate_schema(200)

      assert [%{"id" => activity_id2}] = results["statuses"]
      assert [] = results["accounts"]

      assert activity_id1 != activity_id2
    end

    test "search returns results only for the given type", %{conn: conn} do
      user = insert(:user)
      _user_two = insert(:user, %{nickname: "shp@heldscal.la", name: "I love 2hu"})

      {:ok, _activity} = CommonAPI.post(user, %{status: "This is about 2hu"})

      assert %{"statuses" => [_activity], "accounts" => [], "hashtags" => []} =
               conn
               |> get("/api/v1/search?q=2hu&type=statuses")
               |> json_response_and_validate_schema(200)

      assert %{"statuses" => [], "accounts" => [_user_two], "hashtags" => []} =
               conn
               |> get("/api/v1/search?q=2hu&type=accounts")
               |> json_response_and_validate_schema(200)
    end

    test "search uses account_id to filter statuses by the author", %{conn: conn} do
      user = insert(:user, %{nickname: "shp@shitposter.club"})
      user_two = insert(:user, %{nickname: "shp@heldscal.la", name: "I love 2hu"})

      {:ok, activity1} = CommonAPI.post(user, %{status: "This is about 2hu"})
      {:ok, activity2} = CommonAPI.post(user_two, %{status: "This is also about 2hu"})

      results =
        conn
        |> get("/api/v1/search?q=2hu&account_id=#{user.id}")
        |> json_response_and_validate_schema(200)

      assert [%{"id" => activity_id1}] = results["statuses"]
      assert activity_id1 == activity1.id
      assert [_] = results["accounts"]

      results =
        conn
        |> get("/api/v1/search?q=2hu&account_id=#{user_two.id}")
        |> json_response_and_validate_schema(200)

      assert [%{"id" => activity_id2}] = results["statuses"]
      assert activity_id2 == activity2.id
    end
  end
end
