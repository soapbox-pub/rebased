# Pleroma: A lightweight social networking server
# Copyright © 2017-2021 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.AdminAPI.RelayControllerTest do
  use Pleroma.Web.ConnCase

  import Pleroma.Factory

  alias Pleroma.ModerationLog
  alias Pleroma.Repo
  alias Pleroma.User

  setup_all do
    Tesla.Mock.mock_global(fn env -> apply(HttpRequestMock, :request, [env]) end)

    :ok
  end

  setup do
    admin = insert(:user, is_admin: true)
    token = insert(:oauth_admin_token, user: admin)

    conn =
      build_conn()
      |> assign(:user, admin)
      |> assign(:token, token)

    {:ok, %{admin: admin, token: token, conn: conn}}
  end

  describe "relays" do
    test "POST /relay", %{conn: conn, admin: admin} do
      conn =
        conn
        |> put_req_header("content-type", "application/json")
        |> post("/api/pleroma/admin/relay", %{
          relay_url: "http://mastodon.example.org/users/admin"
        })

      assert json_response_and_validate_schema(conn, 200) == %{
               "actor" => "http://mastodon.example.org/users/admin",
               "followed_back" => false
             }

      log_entry = Repo.one(ModerationLog)

      assert ModerationLog.get_log_entry_message(log_entry) ==
               "@#{admin.nickname} followed relay: http://mastodon.example.org/users/admin"
    end

    test "GET /relay", %{conn: conn} do
      relay_user = Pleroma.Web.ActivityPub.Relay.get_actor()

      ["http://mastodon.example.org/users/admin", "https://mstdn.io/users/mayuutann"]
      |> Enum.each(fn ap_id ->
        {:ok, user} = User.get_or_fetch_by_ap_id(ap_id)
        User.follow(relay_user, user)
      end)

      conn = get(conn, "/api/pleroma/admin/relay")

      assert json_response_and_validate_schema(conn, 200)["relays"] |> Enum.sort() == [
               %{
                 "actor" => "http://mastodon.example.org/users/admin",
                 "followed_back" => true
               },
               %{"actor" => "https://mstdn.io/users/mayuutann", "followed_back" => true}
             ]
    end

    test "DELETE /relay", %{conn: conn, admin: admin} do
      conn
      |> put_req_header("content-type", "application/json")
      |> post("/api/pleroma/admin/relay", %{
        relay_url: "http://mastodon.example.org/users/admin"
      })

      conn =
        conn
        |> put_req_header("content-type", "application/json")
        |> delete("/api/pleroma/admin/relay", %{
          relay_url: "http://mastodon.example.org/users/admin"
        })

      assert json_response_and_validate_schema(conn, 200) ==
               "http://mastodon.example.org/users/admin"

      [log_entry_one, log_entry_two] = Repo.all(ModerationLog)

      assert ModerationLog.get_log_entry_message(log_entry_one) ==
               "@#{admin.nickname} followed relay: http://mastodon.example.org/users/admin"

      assert ModerationLog.get_log_entry_message(log_entry_two) ==
               "@#{admin.nickname} unfollowed relay: http://mastodon.example.org/users/admin"
    end
  end
end
