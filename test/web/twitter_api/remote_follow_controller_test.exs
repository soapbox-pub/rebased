# Pleroma: A lightweight social networking server
# Copyright © 2017-2019 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.TwitterAPI.RemoteFollowControllerTest do
  use Pleroma.Web.ConnCase

  alias Pleroma.User
  alias Pleroma.Web.CommonAPI
  import ExUnit.CaptureLog
  import Pleroma.Factory

  setup do
    Tesla.Mock.mock(fn env -> apply(HttpRequestMock, :request, [env]) end)
    :ok
  end

  clear_config([:instance])
  clear_config([:frontend_configurations, :pleroma_fe])
  clear_config([:user, :deny_follow_blocked])

  describe "GET /ostatus_subscribe - remote_follow/2" do
    test "adds status to pleroma instance if the `acct` is a status", %{conn: conn} do
      conn =
        get(
          conn,
          "/ostatus_subscribe?acct=https://mastodon.social/users/emelie/statuses/101849165031453009"
        )

      assert redirected_to(conn) =~ "/notice/"
    end

    test "show follow account page if the `acct` is a account link", %{conn: conn} do
      response =
        conn
        |> get("/ostatus_subscribe?acct=https://mastodon.social/users/emelie")
        |> html_response(200)

      assert response =~ "Log in to follow"
    end

    test "show follow page if the `acct` is a account link", %{conn: conn} do
      user = insert(:user)

      response =
        conn
        |> assign(:user, user)
        |> get("/ostatus_subscribe?acct=https://mastodon.social/users/emelie")
        |> html_response(200)

      assert response =~ "Remote follow"
    end

    test "show follow page with error when user cannot fecth by `acct` link", %{conn: conn} do
      user = insert(:user)

      assert capture_log(fn ->
               response =
                 conn
                 |> assign(:user, user)
                 |> get("/ostatus_subscribe?acct=https://mastodon.social/users/not_found")

               assert html_response(response, 200) =~ "Error fetching user"
             end) =~ "Object has been deleted"
    end
  end

  describe "POST /ostatus_subscribe - do_remote_follow/2 with assigned user " do
    test "follows user", %{conn: conn} do
      user = insert(:user)
      user2 = insert(:user)

      response =
        conn
        |> assign(:user, user)
        |> post("/ostatus_subscribe", %{"user" => %{"id" => user2.id}})
        |> response(200)

      assert response =~ "Account followed!"
      assert user2.follower_address in User.following(user)
    end

    test "returns error when user is deactivated", %{conn: conn} do
      user = insert(:user, deactivated: true)
      user2 = insert(:user)

      response =
        conn
        |> assign(:user, user)
        |> post("/ostatus_subscribe", %{"user" => %{"id" => user2.id}})
        |> response(200)

      assert response =~ "Error following account"
    end

    test "returns error when user is blocked", %{conn: conn} do
      Pleroma.Config.put([:user, :deny_follow_blocked], true)
      user = insert(:user)
      user2 = insert(:user)

      {:ok, _user_block} = Pleroma.User.block(user2, user)

      response =
        conn
        |> assign(:user, user)
        |> post("/ostatus_subscribe", %{"user" => %{"id" => user2.id}})
        |> response(200)

      assert response =~ "Error following account"
    end

    test "returns error when followee not found", %{conn: conn} do
      user = insert(:user)

      response =
        conn
        |> assign(:user, user)
        |> post("/ostatus_subscribe", %{"user" => %{"id" => "jimm"}})
        |> response(200)

      assert response =~ "Error following account"
    end

    test "returns success result when user already in followers", %{conn: conn} do
      user = insert(:user)
      user2 = insert(:user)
      {:ok, _, _, _} = CommonAPI.follow(user, user2)

      response =
        conn
        |> assign(:user, refresh_record(user))
        |> post("/ostatus_subscribe", %{"user" => %{"id" => user2.id}})
        |> response(200)

      assert response =~ "Account followed!"
    end
  end

  describe "POST /ostatus_subscribe - do_remote_follow/2 without assigned user " do
    test "follows", %{conn: conn} do
      user = insert(:user)
      user2 = insert(:user)

      response =
        conn
        |> post("/ostatus_subscribe", %{
          "authorization" => %{"name" => user.nickname, "password" => "test", "id" => user2.id}
        })
        |> response(200)

      assert response =~ "Account followed!"
      assert user2.follower_address in User.following(user)
    end

    test "returns error when followee not found", %{conn: conn} do
      user = insert(:user)

      response =
        conn
        |> post("/ostatus_subscribe", %{
          "authorization" => %{"name" => user.nickname, "password" => "test", "id" => "jimm"}
        })
        |> response(200)

      assert response =~ "Error following account"
    end

    test "returns error when login invalid", %{conn: conn} do
      user = insert(:user)

      response =
        conn
        |> post("/ostatus_subscribe", %{
          "authorization" => %{"name" => "jimm", "password" => "test", "id" => user.id}
        })
        |> response(200)

      assert response =~ "Wrong username or password"
    end

    test "returns error when password invalid", %{conn: conn} do
      user = insert(:user)
      user2 = insert(:user)

      response =
        conn
        |> post("/ostatus_subscribe", %{
          "authorization" => %{"name" => user.nickname, "password" => "42", "id" => user2.id}
        })
        |> response(200)

      assert response =~ "Wrong username or password"
    end

    test "returns error when user is blocked", %{conn: conn} do
      Pleroma.Config.put([:user, :deny_follow_blocked], true)
      user = insert(:user)
      user2 = insert(:user)
      {:ok, _user_block} = Pleroma.User.block(user2, user)

      response =
        conn
        |> post("/ostatus_subscribe", %{
          "authorization" => %{"name" => user.nickname, "password" => "test", "id" => user2.id}
        })
        |> response(200)

      assert response =~ "Error following account"
    end
  end
end
