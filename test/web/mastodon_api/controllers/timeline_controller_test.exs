# Pleroma: A lightweight social networking server
# Copyright © 2017-2019 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.MastodonAPI.TimelineControllerTest do
  use Pleroma.Web.ConnCase

  import Pleroma.Factory
  import Tesla.Mock

  alias Pleroma.Config
  alias Pleroma.User
  alias Pleroma.Web.CommonAPI

  clear_config([:instance, :public])

  setup do
    mock(fn env -> apply(HttpRequestMock, :request, [env]) end)
    :ok
  end

  describe "home" do
    test "the home timeline", %{conn: conn} do
      user = insert(:user)
      following = insert(:user)

      {:ok, _activity} = CommonAPI.post(following, %{"status" => "test"})

      conn =
        conn
        |> assign(:user, user)
        |> get("/api/v1/timelines/home")

      assert Enum.empty?(json_response(conn, :ok))

      {:ok, user} = User.follow(user, following)

      conn =
        build_conn()
        |> assign(:user, user)
        |> get("/api/v1/timelines/home")

      assert [%{"content" => "test"}] = json_response(conn, :ok)
    end

    test "the home timeline when the direct messages are excluded", %{conn: conn} do
      user = insert(:user)
      {:ok, public_activity} = CommonAPI.post(user, %{"status" => ".", "visibility" => "public"})
      {:ok, direct_activity} = CommonAPI.post(user, %{"status" => ".", "visibility" => "direct"})

      {:ok, unlisted_activity} =
        CommonAPI.post(user, %{"status" => ".", "visibility" => "unlisted"})

      {:ok, private_activity} =
        CommonAPI.post(user, %{"status" => ".", "visibility" => "private"})

      conn =
        conn
        |> assign(:user, user)
        |> get("/api/v1/timelines/home", %{"exclude_visibilities" => ["direct"]})

      assert status_ids = json_response(conn, :ok) |> Enum.map(& &1["id"])
      assert public_activity.id in status_ids
      assert unlisted_activity.id in status_ids
      assert private_activity.id in status_ids
      refute direct_activity.id in status_ids
    end
  end

  describe "public" do
    @tag capture_log: true
    test "the public timeline", %{conn: conn} do
      following = insert(:user)

      {:ok, _activity} = CommonAPI.post(following, %{"status" => "test"})

      _activity = insert(:note_activity, local: false)

      conn = get(conn, "/api/v1/timelines/public", %{"local" => "False"})

      assert length(json_response(conn, :ok)) == 2

      conn = get(build_conn(), "/api/v1/timelines/public", %{"local" => "True"})

      assert [%{"content" => "test"}] = json_response(conn, :ok)

      conn = get(build_conn(), "/api/v1/timelines/public", %{"local" => "1"})

      assert [%{"content" => "test"}] = json_response(conn, :ok)
    end

    test "the public timeline when public is set to false", %{conn: conn} do
      Config.put([:instance, :public], false)

      assert %{"error" => "This resource requires authentication."} ==
               conn
               |> get("/api/v1/timelines/public", %{"local" => "False"})
               |> json_response(:forbidden)
    end

    test "the public timeline includes only public statuses for an authenticated user" do
      user = insert(:user)

      conn =
        build_conn()
        |> assign(:user, user)

      {:ok, _activity} = CommonAPI.post(user, %{"status" => "test"})
      {:ok, _activity} = CommonAPI.post(user, %{"status" => "test", "visibility" => "private"})
      {:ok, _activity} = CommonAPI.post(user, %{"status" => "test", "visibility" => "unlisted"})
      {:ok, _activity} = CommonAPI.post(user, %{"status" => "test", "visibility" => "direct"})

      res_conn = get(conn, "/api/v1/timelines/public")
      assert length(json_response(res_conn, 200)) == 1
    end
  end

  describe "direct" do
    test "direct timeline", %{conn: conn} do
      user_one = insert(:user)
      user_two = insert(:user)

      {:ok, user_two} = User.follow(user_two, user_one)

      {:ok, direct} =
        CommonAPI.post(user_one, %{
          "status" => "Hi @#{user_two.nickname}!",
          "visibility" => "direct"
        })

      {:ok, _follower_only} =
        CommonAPI.post(user_one, %{
          "status" => "Hi @#{user_two.nickname}!",
          "visibility" => "private"
        })

      # Only direct should be visible here
      res_conn =
        conn
        |> assign(:user, user_two)
        |> get("api/v1/timelines/direct")

      [status] = json_response(res_conn, :ok)

      assert %{"visibility" => "direct"} = status
      assert status["url"] != direct.data["id"]

      # User should be able to see their own direct message
      res_conn =
        build_conn()
        |> assign(:user, user_one)
        |> get("api/v1/timelines/direct")

      [status] = json_response(res_conn, :ok)

      assert %{"visibility" => "direct"} = status

      # Both should be visible here
      res_conn =
        conn
        |> assign(:user, user_two)
        |> get("api/v1/timelines/home")

      [_s1, _s2] = json_response(res_conn, :ok)

      # Test pagination
      Enum.each(1..20, fn _ ->
        {:ok, _} =
          CommonAPI.post(user_one, %{
            "status" => "Hi @#{user_two.nickname}!",
            "visibility" => "direct"
          })
      end)

      res_conn =
        conn
        |> assign(:user, user_two)
        |> get("api/v1/timelines/direct")

      statuses = json_response(res_conn, :ok)
      assert length(statuses) == 20

      res_conn =
        conn
        |> assign(:user, user_two)
        |> get("api/v1/timelines/direct", %{max_id: List.last(statuses)["id"]})

      [status] = json_response(res_conn, :ok)

      assert status["url"] != direct.data["id"]
    end

    test "doesn't include DMs from blocked users", %{conn: conn} do
      blocker = insert(:user)
      blocked = insert(:user)
      user = insert(:user)
      {:ok, blocker} = User.block(blocker, blocked)

      {:ok, _blocked_direct} =
        CommonAPI.post(blocked, %{
          "status" => "Hi @#{blocker.nickname}!",
          "visibility" => "direct"
        })

      {:ok, direct} =
        CommonAPI.post(user, %{
          "status" => "Hi @#{blocker.nickname}!",
          "visibility" => "direct"
        })

      res_conn =
        conn
        |> assign(:user, user)
        |> get("api/v1/timelines/direct")

      [status] = json_response(res_conn, :ok)
      assert status["id"] == direct.id
    end
  end

  describe "list" do
    test "list timeline", %{conn: conn} do
      user = insert(:user)
      other_user = insert(:user)
      {:ok, _activity_one} = CommonAPI.post(user, %{"status" => "Marisa is cute."})
      {:ok, activity_two} = CommonAPI.post(other_user, %{"status" => "Marisa is cute."})
      {:ok, list} = Pleroma.List.create("name", user)
      {:ok, list} = Pleroma.List.follow(list, other_user)

      conn =
        conn
        |> assign(:user, user)
        |> get("/api/v1/timelines/list/#{list.id}")

      assert [%{"id" => id}] = json_response(conn, :ok)

      assert id == to_string(activity_two.id)
    end

    test "list timeline does not leak non-public statuses for unfollowed users", %{conn: conn} do
      user = insert(:user)
      other_user = insert(:user)
      {:ok, activity_one} = CommonAPI.post(other_user, %{"status" => "Marisa is cute."})

      {:ok, _activity_two} =
        CommonAPI.post(other_user, %{
          "status" => "Marisa is cute.",
          "visibility" => "private"
        })

      {:ok, list} = Pleroma.List.create("name", user)
      {:ok, list} = Pleroma.List.follow(list, other_user)

      conn =
        conn
        |> assign(:user, user)
        |> get("/api/v1/timelines/list/#{list.id}")

      assert [%{"id" => id}] = json_response(conn, :ok)

      assert id == to_string(activity_one.id)
    end
  end

  describe "hashtag" do
    @tag capture_log: true
    test "hashtag timeline", %{conn: conn} do
      following = insert(:user)

      {:ok, activity} = CommonAPI.post(following, %{"status" => "test #2hu"})

      nconn = get(conn, "/api/v1/timelines/tag/2hu")

      assert [%{"id" => id}] = json_response(nconn, :ok)

      assert id == to_string(activity.id)

      # works for different capitalization too
      nconn = get(conn, "/api/v1/timelines/tag/2HU")

      assert [%{"id" => id}] = json_response(nconn, :ok)

      assert id == to_string(activity.id)
    end

    test "multi-hashtag timeline", %{conn: conn} do
      user = insert(:user)

      {:ok, activity_test} = CommonAPI.post(user, %{"status" => "#test"})
      {:ok, activity_test1} = CommonAPI.post(user, %{"status" => "#test #test1"})
      {:ok, activity_none} = CommonAPI.post(user, %{"status" => "#test #none"})

      any_test = get(conn, "/api/v1/timelines/tag/test", %{"any" => ["test1"]})

      [status_none, status_test1, status_test] = json_response(any_test, :ok)

      assert to_string(activity_test.id) == status_test["id"]
      assert to_string(activity_test1.id) == status_test1["id"]
      assert to_string(activity_none.id) == status_none["id"]

      restricted_test =
        get(conn, "/api/v1/timelines/tag/test", %{"all" => ["test1"], "none" => ["none"]})

      assert [status_test1] == json_response(restricted_test, :ok)

      all_test = get(conn, "/api/v1/timelines/tag/test", %{"all" => ["none"]})

      assert [status_none] == json_response(all_test, :ok)
    end
  end
end
