# Pleroma: A lightweight social networking server
# Copyright © 2017-2020 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.AdminAPI.AdminAPIControllerTest do
  use Pleroma.Web.ConnCase
  use Oban.Testing, repo: Pleroma.Repo

  import ExUnit.CaptureLog
  import Mock
  import Pleroma.Factory

  alias Pleroma.Activity
  alias Pleroma.Config
  alias Pleroma.HTML
  alias Pleroma.MFA
  alias Pleroma.ModerationLog
  alias Pleroma.Repo
  alias Pleroma.Tests.ObanHelpers
  alias Pleroma.User
  alias Pleroma.Web
  alias Pleroma.Web.ActivityPub.Relay
  alias Pleroma.Web.CommonAPI
  alias Pleroma.Web.MediaProxy

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

  describe "with [:auth, :enforce_oauth_admin_scope_usage]," do
    setup do: clear_config([:auth, :enforce_oauth_admin_scope_usage], true)

    test "GET /api/pleroma/admin/users/:nickname requires admin:read:accounts or broader scope",
         %{admin: admin} do
      user = insert(:user)
      url = "/api/pleroma/admin/users/#{user.nickname}"

      good_token1 = insert(:oauth_token, user: admin, scopes: ["admin"])
      good_token2 = insert(:oauth_token, user: admin, scopes: ["admin:read"])
      good_token3 = insert(:oauth_token, user: admin, scopes: ["admin:read:accounts"])

      bad_token1 = insert(:oauth_token, user: admin, scopes: ["read:accounts"])
      bad_token2 = insert(:oauth_token, user: admin, scopes: ["admin:read:accounts:partial"])
      bad_token3 = nil

      for good_token <- [good_token1, good_token2, good_token3] do
        conn =
          build_conn()
          |> assign(:user, admin)
          |> assign(:token, good_token)
          |> get(url)

        assert json_response(conn, 200)
      end

      for good_token <- [good_token1, good_token2, good_token3] do
        conn =
          build_conn()
          |> assign(:user, nil)
          |> assign(:token, good_token)
          |> get(url)

        assert json_response(conn, :forbidden)
      end

      for bad_token <- [bad_token1, bad_token2, bad_token3] do
        conn =
          build_conn()
          |> assign(:user, admin)
          |> assign(:token, bad_token)
          |> get(url)

        assert json_response(conn, :forbidden)
      end
    end
  end

  describe "unless [:auth, :enforce_oauth_admin_scope_usage]," do
    setup do: clear_config([:auth, :enforce_oauth_admin_scope_usage], false)

    test "GET /api/pleroma/admin/users/:nickname requires " <>
           "read:accounts or admin:read:accounts or broader scope",
         %{admin: admin} do
      user = insert(:user)
      url = "/api/pleroma/admin/users/#{user.nickname}"

      good_token1 = insert(:oauth_token, user: admin, scopes: ["admin"])
      good_token2 = insert(:oauth_token, user: admin, scopes: ["admin:read"])
      good_token3 = insert(:oauth_token, user: admin, scopes: ["admin:read:accounts"])
      good_token4 = insert(:oauth_token, user: admin, scopes: ["read:accounts"])
      good_token5 = insert(:oauth_token, user: admin, scopes: ["read"])

      good_tokens = [good_token1, good_token2, good_token3, good_token4, good_token5]

      bad_token1 = insert(:oauth_token, user: admin, scopes: ["read:accounts:partial"])
      bad_token2 = insert(:oauth_token, user: admin, scopes: ["admin:read:accounts:partial"])
      bad_token3 = nil

      for good_token <- good_tokens do
        conn =
          build_conn()
          |> assign(:user, admin)
          |> assign(:token, good_token)
          |> get(url)

        assert json_response(conn, 200)
      end

      for good_token <- good_tokens do
        conn =
          build_conn()
          |> assign(:user, nil)
          |> assign(:token, good_token)
          |> get(url)

        assert json_response(conn, :forbidden)
      end

      for bad_token <- [bad_token1, bad_token2, bad_token3] do
        conn =
          build_conn()
          |> assign(:user, admin)
          |> assign(:token, bad_token)
          |> get(url)

        assert json_response(conn, :forbidden)
      end
    end
  end

  describe "DELETE /api/pleroma/admin/users" do
    test "single user", %{admin: admin, conn: conn} do
      user = insert(:user)
      clear_config([:instance, :federating], true)

      with_mock Pleroma.Web.Federator,
        publish: fn _ -> nil end do
        conn =
          conn
          |> put_req_header("accept", "application/json")
          |> delete("/api/pleroma/admin/users?nickname=#{user.nickname}")

        ObanHelpers.perform_all()

        assert User.get_by_nickname(user.nickname).deactivated

        log_entry = Repo.one(ModerationLog)

        assert ModerationLog.get_log_entry_message(log_entry) ==
                 "@#{admin.nickname} deleted users: @#{user.nickname}"

        assert json_response(conn, 200) == [user.nickname]

        assert called(Pleroma.Web.Federator.publish(:_))
      end
    end

    test "multiple users", %{admin: admin, conn: conn} do
      user_one = insert(:user)
      user_two = insert(:user)

      conn =
        conn
        |> put_req_header("accept", "application/json")
        |> delete("/api/pleroma/admin/users", %{
          nicknames: [user_one.nickname, user_two.nickname]
        })

      log_entry = Repo.one(ModerationLog)

      assert ModerationLog.get_log_entry_message(log_entry) ==
               "@#{admin.nickname} deleted users: @#{user_one.nickname}, @#{user_two.nickname}"

      response = json_response(conn, 200)
      assert response -- [user_one.nickname, user_two.nickname] == []
    end
  end

  describe "/api/pleroma/admin/users" do
    test "Create", %{conn: conn} do
      conn =
        conn
        |> put_req_header("accept", "application/json")
        |> post("/api/pleroma/admin/users", %{
          "users" => [
            %{
              "nickname" => "lain",
              "email" => "lain@example.org",
              "password" => "test"
            },
            %{
              "nickname" => "lain2",
              "email" => "lain2@example.org",
              "password" => "test"
            }
          ]
        })

      response = json_response(conn, 200) |> Enum.map(&Map.get(&1, "type"))
      assert response == ["success", "success"]

      log_entry = Repo.one(ModerationLog)

      assert ["lain", "lain2"] -- Enum.map(log_entry.data["subjects"], & &1["nickname"]) == []
    end

    test "Cannot create user with existing email", %{conn: conn} do
      user = insert(:user)

      conn =
        conn
        |> put_req_header("accept", "application/json")
        |> post("/api/pleroma/admin/users", %{
          "users" => [
            %{
              "nickname" => "lain",
              "email" => user.email,
              "password" => "test"
            }
          ]
        })

      assert json_response(conn, 409) == [
               %{
                 "code" => 409,
                 "data" => %{
                   "email" => user.email,
                   "nickname" => "lain"
                 },
                 "error" => "email has already been taken",
                 "type" => "error"
               }
             ]
    end

    test "Cannot create user with existing nickname", %{conn: conn} do
      user = insert(:user)

      conn =
        conn
        |> put_req_header("accept", "application/json")
        |> post("/api/pleroma/admin/users", %{
          "users" => [
            %{
              "nickname" => user.nickname,
              "email" => "someuser@plerama.social",
              "password" => "test"
            }
          ]
        })

      assert json_response(conn, 409) == [
               %{
                 "code" => 409,
                 "data" => %{
                   "email" => "someuser@plerama.social",
                   "nickname" => user.nickname
                 },
                 "error" => "nickname has already been taken",
                 "type" => "error"
               }
             ]
    end

    test "Multiple user creation works in transaction", %{conn: conn} do
      user = insert(:user)

      conn =
        conn
        |> put_req_header("accept", "application/json")
        |> post("/api/pleroma/admin/users", %{
          "users" => [
            %{
              "nickname" => "newuser",
              "email" => "newuser@pleroma.social",
              "password" => "test"
            },
            %{
              "nickname" => "lain",
              "email" => user.email,
              "password" => "test"
            }
          ]
        })

      assert json_response(conn, 409) == [
               %{
                 "code" => 409,
                 "data" => %{
                   "email" => user.email,
                   "nickname" => "lain"
                 },
                 "error" => "email has already been taken",
                 "type" => "error"
               },
               %{
                 "code" => 409,
                 "data" => %{
                   "email" => "newuser@pleroma.social",
                   "nickname" => "newuser"
                 },
                 "error" => "",
                 "type" => "error"
               }
             ]

      assert User.get_by_nickname("newuser") === nil
    end
  end

  describe "/api/pleroma/admin/users/:nickname" do
    test "Show", %{conn: conn} do
      user = insert(:user)

      conn = get(conn, "/api/pleroma/admin/users/#{user.nickname}")

      expected = %{
        "deactivated" => false,
        "id" => to_string(user.id),
        "local" => true,
        "nickname" => user.nickname,
        "roles" => %{"admin" => false, "moderator" => false},
        "tags" => [],
        "avatar" => User.avatar_url(user) |> MediaProxy.url(),
        "display_name" => HTML.strip_tags(user.name || user.nickname),
        "confirmation_pending" => false
      }

      assert expected == json_response(conn, 200)
    end

    test "when the user doesn't exist", %{conn: conn} do
      user = build(:user)

      conn = get(conn, "/api/pleroma/admin/users/#{user.nickname}")

      assert %{"error" => "Not found"} == json_response(conn, 404)
    end
  end

  describe "/api/pleroma/admin/users/follow" do
    test "allows to force-follow another user", %{admin: admin, conn: conn} do
      user = insert(:user)
      follower = insert(:user)

      conn
      |> put_req_header("accept", "application/json")
      |> post("/api/pleroma/admin/users/follow", %{
        "follower" => follower.nickname,
        "followed" => user.nickname
      })

      user = User.get_cached_by_id(user.id)
      follower = User.get_cached_by_id(follower.id)

      assert User.following?(follower, user)

      log_entry = Repo.one(ModerationLog)

      assert ModerationLog.get_log_entry_message(log_entry) ==
               "@#{admin.nickname} made @#{follower.nickname} follow @#{user.nickname}"
    end
  end

  describe "/api/pleroma/admin/users/unfollow" do
    test "allows to force-unfollow another user", %{admin: admin, conn: conn} do
      user = insert(:user)
      follower = insert(:user)

      User.follow(follower, user)

      conn
      |> put_req_header("accept", "application/json")
      |> post("/api/pleroma/admin/users/unfollow", %{
        "follower" => follower.nickname,
        "followed" => user.nickname
      })

      user = User.get_cached_by_id(user.id)
      follower = User.get_cached_by_id(follower.id)

      refute User.following?(follower, user)

      log_entry = Repo.one(ModerationLog)

      assert ModerationLog.get_log_entry_message(log_entry) ==
               "@#{admin.nickname} made @#{follower.nickname} unfollow @#{user.nickname}"
    end
  end

  describe "PUT /api/pleroma/admin/users/tag" do
    setup %{conn: conn} do
      user1 = insert(:user, %{tags: ["x"]})
      user2 = insert(:user, %{tags: ["y"]})
      user3 = insert(:user, %{tags: ["unchanged"]})

      conn =
        conn
        |> put_req_header("accept", "application/json")
        |> put(
          "/api/pleroma/admin/users/tag?nicknames[]=#{user1.nickname}&nicknames[]=" <>
            "#{user2.nickname}&tags[]=foo&tags[]=bar"
        )

      %{conn: conn, user1: user1, user2: user2, user3: user3}
    end

    test "it appends specified tags to users with specified nicknames", %{
      conn: conn,
      admin: admin,
      user1: user1,
      user2: user2
    } do
      assert json_response(conn, :no_content)
      assert User.get_cached_by_id(user1.id).tags == ["x", "foo", "bar"]
      assert User.get_cached_by_id(user2.id).tags == ["y", "foo", "bar"]

      log_entry = Repo.one(ModerationLog)

      users =
        [user1.nickname, user2.nickname]
        |> Enum.map(&"@#{&1}")
        |> Enum.join(", ")

      tags = ["foo", "bar"] |> Enum.join(", ")

      assert ModerationLog.get_log_entry_message(log_entry) ==
               "@#{admin.nickname} added tags: #{tags} to users: #{users}"
    end

    test "it does not modify tags of not specified users", %{conn: conn, user3: user3} do
      assert json_response(conn, :no_content)
      assert User.get_cached_by_id(user3.id).tags == ["unchanged"]
    end
  end

  describe "DELETE /api/pleroma/admin/users/tag" do
    setup %{conn: conn} do
      user1 = insert(:user, %{tags: ["x"]})
      user2 = insert(:user, %{tags: ["y", "z"]})
      user3 = insert(:user, %{tags: ["unchanged"]})

      conn =
        conn
        |> put_req_header("accept", "application/json")
        |> delete(
          "/api/pleroma/admin/users/tag?nicknames[]=#{user1.nickname}&nicknames[]=" <>
            "#{user2.nickname}&tags[]=x&tags[]=z"
        )

      %{conn: conn, user1: user1, user2: user2, user3: user3}
    end

    test "it removes specified tags from users with specified nicknames", %{
      conn: conn,
      admin: admin,
      user1: user1,
      user2: user2
    } do
      assert json_response(conn, :no_content)
      assert User.get_cached_by_id(user1.id).tags == []
      assert User.get_cached_by_id(user2.id).tags == ["y"]

      log_entry = Repo.one(ModerationLog)

      users =
        [user1.nickname, user2.nickname]
        |> Enum.map(&"@#{&1}")
        |> Enum.join(", ")

      tags = ["x", "z"] |> Enum.join(", ")

      assert ModerationLog.get_log_entry_message(log_entry) ==
               "@#{admin.nickname} removed tags: #{tags} from users: #{users}"
    end

    test "it does not modify tags of not specified users", %{conn: conn, user3: user3} do
      assert json_response(conn, :no_content)
      assert User.get_cached_by_id(user3.id).tags == ["unchanged"]
    end
  end

  describe "/api/pleroma/admin/users/:nickname/permission_group" do
    test "GET is giving user_info", %{admin: admin, conn: conn} do
      conn =
        conn
        |> put_req_header("accept", "application/json")
        |> get("/api/pleroma/admin/users/#{admin.nickname}/permission_group/")

      assert json_response(conn, 200) == %{
               "is_admin" => true,
               "is_moderator" => false
             }
    end

    test "/:right POST, can add to a permission group", %{admin: admin, conn: conn} do
      user = insert(:user)

      conn =
        conn
        |> put_req_header("accept", "application/json")
        |> post("/api/pleroma/admin/users/#{user.nickname}/permission_group/admin")

      assert json_response(conn, 200) == %{
               "is_admin" => true
             }

      log_entry = Repo.one(ModerationLog)

      assert ModerationLog.get_log_entry_message(log_entry) ==
               "@#{admin.nickname} made @#{user.nickname} admin"
    end

    test "/:right POST, can add to a permission group (multiple)", %{admin: admin, conn: conn} do
      user_one = insert(:user)
      user_two = insert(:user)

      conn =
        conn
        |> put_req_header("accept", "application/json")
        |> post("/api/pleroma/admin/users/permission_group/admin", %{
          nicknames: [user_one.nickname, user_two.nickname]
        })

      assert json_response(conn, 200) == %{"is_admin" => true}

      log_entry = Repo.one(ModerationLog)

      assert ModerationLog.get_log_entry_message(log_entry) ==
               "@#{admin.nickname} made @#{user_one.nickname}, @#{user_two.nickname} admin"
    end

    test "/:right DELETE, can remove from a permission group", %{admin: admin, conn: conn} do
      user = insert(:user, is_admin: true)

      conn =
        conn
        |> put_req_header("accept", "application/json")
        |> delete("/api/pleroma/admin/users/#{user.nickname}/permission_group/admin")

      assert json_response(conn, 200) == %{"is_admin" => false}

      log_entry = Repo.one(ModerationLog)

      assert ModerationLog.get_log_entry_message(log_entry) ==
               "@#{admin.nickname} revoked admin role from @#{user.nickname}"
    end

    test "/:right DELETE, can remove from a permission group (multiple)", %{
      admin: admin,
      conn: conn
    } do
      user_one = insert(:user, is_admin: true)
      user_two = insert(:user, is_admin: true)

      conn =
        conn
        |> put_req_header("accept", "application/json")
        |> delete("/api/pleroma/admin/users/permission_group/admin", %{
          nicknames: [user_one.nickname, user_two.nickname]
        })

      assert json_response(conn, 200) == %{"is_admin" => false}

      log_entry = Repo.one(ModerationLog)

      assert ModerationLog.get_log_entry_message(log_entry) ==
               "@#{admin.nickname} revoked admin role from @#{user_one.nickname}, @#{
                 user_two.nickname
               }"
    end
  end

  test "/api/pleroma/admin/users/:nickname/password_reset", %{conn: conn} do
    user = insert(:user)

    conn =
      conn
      |> put_req_header("accept", "application/json")
      |> get("/api/pleroma/admin/users/#{user.nickname}/password_reset")

    resp = json_response(conn, 200)

    assert Regex.match?(~r/(http:\/\/|https:\/\/)/, resp["link"])
  end

  describe "GET /api/pleroma/admin/users" do
    test "renders users array for the first page", %{conn: conn, admin: admin} do
      user = insert(:user, local: false, tags: ["foo", "bar"])
      conn = get(conn, "/api/pleroma/admin/users?page=1")

      users =
        [
          %{
            "deactivated" => admin.deactivated,
            "id" => admin.id,
            "nickname" => admin.nickname,
            "roles" => %{"admin" => true, "moderator" => false},
            "local" => true,
            "tags" => [],
            "avatar" => User.avatar_url(admin) |> MediaProxy.url(),
            "display_name" => HTML.strip_tags(admin.name || admin.nickname),
            "confirmation_pending" => false
          },
          %{
            "deactivated" => user.deactivated,
            "id" => user.id,
            "nickname" => user.nickname,
            "roles" => %{"admin" => false, "moderator" => false},
            "local" => false,
            "tags" => ["foo", "bar"],
            "avatar" => User.avatar_url(user) |> MediaProxy.url(),
            "display_name" => HTML.strip_tags(user.name || user.nickname),
            "confirmation_pending" => false
          }
        ]
        |> Enum.sort_by(& &1["nickname"])

      assert json_response(conn, 200) == %{
               "count" => 2,
               "page_size" => 50,
               "users" => users
             }
    end

    test "pagination works correctly with service users", %{conn: conn} do
      service1 = User.get_or_create_service_actor_by_ap_id(Web.base_url() <> "/meido", "meido")

      insert_list(25, :user)

      assert %{"count" => 26, "page_size" => 10, "users" => users1} =
               conn
               |> get("/api/pleroma/admin/users?page=1&filters=", %{page_size: "10"})
               |> json_response(200)

      assert Enum.count(users1) == 10
      assert service1 not in users1

      assert %{"count" => 26, "page_size" => 10, "users" => users2} =
               conn
               |> get("/api/pleroma/admin/users?page=2&filters=", %{page_size: "10"})
               |> json_response(200)

      assert Enum.count(users2) == 10
      assert service1 not in users2

      assert %{"count" => 26, "page_size" => 10, "users" => users3} =
               conn
               |> get("/api/pleroma/admin/users?page=3&filters=", %{page_size: "10"})
               |> json_response(200)

      assert Enum.count(users3) == 6
      assert service1 not in users3
    end

    test "renders empty array for the second page", %{conn: conn} do
      insert(:user)

      conn = get(conn, "/api/pleroma/admin/users?page=2")

      assert json_response(conn, 200) == %{
               "count" => 2,
               "page_size" => 50,
               "users" => []
             }
    end

    test "regular search", %{conn: conn} do
      user = insert(:user, nickname: "bob")

      conn = get(conn, "/api/pleroma/admin/users?query=bo")

      assert json_response(conn, 200) == %{
               "count" => 1,
               "page_size" => 50,
               "users" => [
                 %{
                   "deactivated" => user.deactivated,
                   "id" => user.id,
                   "nickname" => user.nickname,
                   "roles" => %{"admin" => false, "moderator" => false},
                   "local" => true,
                   "tags" => [],
                   "avatar" => User.avatar_url(user) |> MediaProxy.url(),
                   "display_name" => HTML.strip_tags(user.name || user.nickname),
                   "confirmation_pending" => false
                 }
               ]
             }
    end

    test "search by domain", %{conn: conn} do
      user = insert(:user, nickname: "nickname@domain.com")
      insert(:user)

      conn = get(conn, "/api/pleroma/admin/users?query=domain.com")

      assert json_response(conn, 200) == %{
               "count" => 1,
               "page_size" => 50,
               "users" => [
                 %{
                   "deactivated" => user.deactivated,
                   "id" => user.id,
                   "nickname" => user.nickname,
                   "roles" => %{"admin" => false, "moderator" => false},
                   "local" => true,
                   "tags" => [],
                   "avatar" => User.avatar_url(user) |> MediaProxy.url(),
                   "display_name" => HTML.strip_tags(user.name || user.nickname),
                   "confirmation_pending" => false
                 }
               ]
             }
    end

    test "search by full nickname", %{conn: conn} do
      user = insert(:user, nickname: "nickname@domain.com")
      insert(:user)

      conn = get(conn, "/api/pleroma/admin/users?query=nickname@domain.com")

      assert json_response(conn, 200) == %{
               "count" => 1,
               "page_size" => 50,
               "users" => [
                 %{
                   "deactivated" => user.deactivated,
                   "id" => user.id,
                   "nickname" => user.nickname,
                   "roles" => %{"admin" => false, "moderator" => false},
                   "local" => true,
                   "tags" => [],
                   "avatar" => User.avatar_url(user) |> MediaProxy.url(),
                   "display_name" => HTML.strip_tags(user.name || user.nickname),
                   "confirmation_pending" => false
                 }
               ]
             }
    end

    test "search by display name", %{conn: conn} do
      user = insert(:user, name: "Display name")
      insert(:user)

      conn = get(conn, "/api/pleroma/admin/users?name=display")

      assert json_response(conn, 200) == %{
               "count" => 1,
               "page_size" => 50,
               "users" => [
                 %{
                   "deactivated" => user.deactivated,
                   "id" => user.id,
                   "nickname" => user.nickname,
                   "roles" => %{"admin" => false, "moderator" => false},
                   "local" => true,
                   "tags" => [],
                   "avatar" => User.avatar_url(user) |> MediaProxy.url(),
                   "display_name" => HTML.strip_tags(user.name || user.nickname),
                   "confirmation_pending" => false
                 }
               ]
             }
    end

    test "search by email", %{conn: conn} do
      user = insert(:user, email: "email@example.com")
      insert(:user)

      conn = get(conn, "/api/pleroma/admin/users?email=email@example.com")

      assert json_response(conn, 200) == %{
               "count" => 1,
               "page_size" => 50,
               "users" => [
                 %{
                   "deactivated" => user.deactivated,
                   "id" => user.id,
                   "nickname" => user.nickname,
                   "roles" => %{"admin" => false, "moderator" => false},
                   "local" => true,
                   "tags" => [],
                   "avatar" => User.avatar_url(user) |> MediaProxy.url(),
                   "display_name" => HTML.strip_tags(user.name || user.nickname),
                   "confirmation_pending" => false
                 }
               ]
             }
    end

    test "regular search with page size", %{conn: conn} do
      user = insert(:user, nickname: "aalice")
      user2 = insert(:user, nickname: "alice")

      conn1 = get(conn, "/api/pleroma/admin/users?query=a&page_size=1&page=1")

      assert json_response(conn1, 200) == %{
               "count" => 2,
               "page_size" => 1,
               "users" => [
                 %{
                   "deactivated" => user.deactivated,
                   "id" => user.id,
                   "nickname" => user.nickname,
                   "roles" => %{"admin" => false, "moderator" => false},
                   "local" => true,
                   "tags" => [],
                   "avatar" => User.avatar_url(user) |> MediaProxy.url(),
                   "display_name" => HTML.strip_tags(user.name || user.nickname),
                   "confirmation_pending" => false
                 }
               ]
             }

      conn2 = get(conn, "/api/pleroma/admin/users?query=a&page_size=1&page=2")

      assert json_response(conn2, 200) == %{
               "count" => 2,
               "page_size" => 1,
               "users" => [
                 %{
                   "deactivated" => user2.deactivated,
                   "id" => user2.id,
                   "nickname" => user2.nickname,
                   "roles" => %{"admin" => false, "moderator" => false},
                   "local" => true,
                   "tags" => [],
                   "avatar" => User.avatar_url(user2) |> MediaProxy.url(),
                   "display_name" => HTML.strip_tags(user2.name || user2.nickname),
                   "confirmation_pending" => false
                 }
               ]
             }
    end

    test "only local users" do
      admin = insert(:user, is_admin: true, nickname: "john")
      token = insert(:oauth_admin_token, user: admin)
      user = insert(:user, nickname: "bob")

      insert(:user, nickname: "bobb", local: false)

      conn =
        build_conn()
        |> assign(:user, admin)
        |> assign(:token, token)
        |> get("/api/pleroma/admin/users?query=bo&filters=local")

      assert json_response(conn, 200) == %{
               "count" => 1,
               "page_size" => 50,
               "users" => [
                 %{
                   "deactivated" => user.deactivated,
                   "id" => user.id,
                   "nickname" => user.nickname,
                   "roles" => %{"admin" => false, "moderator" => false},
                   "local" => true,
                   "tags" => [],
                   "avatar" => User.avatar_url(user) |> MediaProxy.url(),
                   "display_name" => HTML.strip_tags(user.name || user.nickname),
                   "confirmation_pending" => false
                 }
               ]
             }
    end

    test "only local users with no query", %{conn: conn, admin: old_admin} do
      admin = insert(:user, is_admin: true, nickname: "john")
      user = insert(:user, nickname: "bob")

      insert(:user, nickname: "bobb", local: false)

      conn = get(conn, "/api/pleroma/admin/users?filters=local")

      users =
        [
          %{
            "deactivated" => user.deactivated,
            "id" => user.id,
            "nickname" => user.nickname,
            "roles" => %{"admin" => false, "moderator" => false},
            "local" => true,
            "tags" => [],
            "avatar" => User.avatar_url(user) |> MediaProxy.url(),
            "display_name" => HTML.strip_tags(user.name || user.nickname),
            "confirmation_pending" => false
          },
          %{
            "deactivated" => admin.deactivated,
            "id" => admin.id,
            "nickname" => admin.nickname,
            "roles" => %{"admin" => true, "moderator" => false},
            "local" => true,
            "tags" => [],
            "avatar" => User.avatar_url(admin) |> MediaProxy.url(),
            "display_name" => HTML.strip_tags(admin.name || admin.nickname),
            "confirmation_pending" => false
          },
          %{
            "deactivated" => false,
            "id" => old_admin.id,
            "local" => true,
            "nickname" => old_admin.nickname,
            "roles" => %{"admin" => true, "moderator" => false},
            "tags" => [],
            "avatar" => User.avatar_url(old_admin) |> MediaProxy.url(),
            "display_name" => HTML.strip_tags(old_admin.name || old_admin.nickname),
            "confirmation_pending" => false
          }
        ]
        |> Enum.sort_by(& &1["nickname"])

      assert json_response(conn, 200) == %{
               "count" => 3,
               "page_size" => 50,
               "users" => users
             }
    end

    test "load only admins", %{conn: conn, admin: admin} do
      second_admin = insert(:user, is_admin: true)
      insert(:user)
      insert(:user)

      conn = get(conn, "/api/pleroma/admin/users?filters=is_admin")

      users =
        [
          %{
            "deactivated" => false,
            "id" => admin.id,
            "nickname" => admin.nickname,
            "roles" => %{"admin" => true, "moderator" => false},
            "local" => admin.local,
            "tags" => [],
            "avatar" => User.avatar_url(admin) |> MediaProxy.url(),
            "display_name" => HTML.strip_tags(admin.name || admin.nickname),
            "confirmation_pending" => false
          },
          %{
            "deactivated" => false,
            "id" => second_admin.id,
            "nickname" => second_admin.nickname,
            "roles" => %{"admin" => true, "moderator" => false},
            "local" => second_admin.local,
            "tags" => [],
            "avatar" => User.avatar_url(second_admin) |> MediaProxy.url(),
            "display_name" => HTML.strip_tags(second_admin.name || second_admin.nickname),
            "confirmation_pending" => false
          }
        ]
        |> Enum.sort_by(& &1["nickname"])

      assert json_response(conn, 200) == %{
               "count" => 2,
               "page_size" => 50,
               "users" => users
             }
    end

    test "load only moderators", %{conn: conn} do
      moderator = insert(:user, is_moderator: true)
      insert(:user)
      insert(:user)

      conn = get(conn, "/api/pleroma/admin/users?filters=is_moderator")

      assert json_response(conn, 200) == %{
               "count" => 1,
               "page_size" => 50,
               "users" => [
                 %{
                   "deactivated" => false,
                   "id" => moderator.id,
                   "nickname" => moderator.nickname,
                   "roles" => %{"admin" => false, "moderator" => true},
                   "local" => moderator.local,
                   "tags" => [],
                   "avatar" => User.avatar_url(moderator) |> MediaProxy.url(),
                   "display_name" => HTML.strip_tags(moderator.name || moderator.nickname),
                   "confirmation_pending" => false
                 }
               ]
             }
    end

    test "load users with tags list", %{conn: conn} do
      user1 = insert(:user, tags: ["first"])
      user2 = insert(:user, tags: ["second"])
      insert(:user)
      insert(:user)

      conn = get(conn, "/api/pleroma/admin/users?tags[]=first&tags[]=second")

      users =
        [
          %{
            "deactivated" => false,
            "id" => user1.id,
            "nickname" => user1.nickname,
            "roles" => %{"admin" => false, "moderator" => false},
            "local" => user1.local,
            "tags" => ["first"],
            "avatar" => User.avatar_url(user1) |> MediaProxy.url(),
            "display_name" => HTML.strip_tags(user1.name || user1.nickname),
            "confirmation_pending" => false
          },
          %{
            "deactivated" => false,
            "id" => user2.id,
            "nickname" => user2.nickname,
            "roles" => %{"admin" => false, "moderator" => false},
            "local" => user2.local,
            "tags" => ["second"],
            "avatar" => User.avatar_url(user2) |> MediaProxy.url(),
            "display_name" => HTML.strip_tags(user2.name || user2.nickname),
            "confirmation_pending" => false
          }
        ]
        |> Enum.sort_by(& &1["nickname"])

      assert json_response(conn, 200) == %{
               "count" => 2,
               "page_size" => 50,
               "users" => users
             }
    end

    test "it works with multiple filters" do
      admin = insert(:user, nickname: "john", is_admin: true)
      token = insert(:oauth_admin_token, user: admin)
      user = insert(:user, nickname: "bob", local: false, deactivated: true)

      insert(:user, nickname: "ken", local: true, deactivated: true)
      insert(:user, nickname: "bobb", local: false, deactivated: false)

      conn =
        build_conn()
        |> assign(:user, admin)
        |> assign(:token, token)
        |> get("/api/pleroma/admin/users?filters=deactivated,external")

      assert json_response(conn, 200) == %{
               "count" => 1,
               "page_size" => 50,
               "users" => [
                 %{
                   "deactivated" => user.deactivated,
                   "id" => user.id,
                   "nickname" => user.nickname,
                   "roles" => %{"admin" => false, "moderator" => false},
                   "local" => user.local,
                   "tags" => [],
                   "avatar" => User.avatar_url(user) |> MediaProxy.url(),
                   "display_name" => HTML.strip_tags(user.name || user.nickname),
                   "confirmation_pending" => false
                 }
               ]
             }
    end

    test "it omits relay user", %{admin: admin, conn: conn} do
      assert %User{} = Relay.get_actor()

      conn = get(conn, "/api/pleroma/admin/users")

      assert json_response(conn, 200) == %{
               "count" => 1,
               "page_size" => 50,
               "users" => [
                 %{
                   "deactivated" => admin.deactivated,
                   "id" => admin.id,
                   "nickname" => admin.nickname,
                   "roles" => %{"admin" => true, "moderator" => false},
                   "local" => true,
                   "tags" => [],
                   "avatar" => User.avatar_url(admin) |> MediaProxy.url(),
                   "display_name" => HTML.strip_tags(admin.name || admin.nickname),
                   "confirmation_pending" => false
                 }
               ]
             }
    end
  end

  test "PATCH /api/pleroma/admin/users/activate", %{admin: admin, conn: conn} do
    user_one = insert(:user, deactivated: true)
    user_two = insert(:user, deactivated: true)

    conn =
      patch(
        conn,
        "/api/pleroma/admin/users/activate",
        %{nicknames: [user_one.nickname, user_two.nickname]}
      )

    response = json_response(conn, 200)
    assert Enum.map(response["users"], & &1["deactivated"]) == [false, false]

    log_entry = Repo.one(ModerationLog)

    assert ModerationLog.get_log_entry_message(log_entry) ==
             "@#{admin.nickname} activated users: @#{user_one.nickname}, @#{user_two.nickname}"
  end

  test "PATCH /api/pleroma/admin/users/deactivate", %{admin: admin, conn: conn} do
    user_one = insert(:user, deactivated: false)
    user_two = insert(:user, deactivated: false)

    conn =
      patch(
        conn,
        "/api/pleroma/admin/users/deactivate",
        %{nicknames: [user_one.nickname, user_two.nickname]}
      )

    response = json_response(conn, 200)
    assert Enum.map(response["users"], & &1["deactivated"]) == [true, true]

    log_entry = Repo.one(ModerationLog)

    assert ModerationLog.get_log_entry_message(log_entry) ==
             "@#{admin.nickname} deactivated users: @#{user_one.nickname}, @#{user_two.nickname}"
  end

  test "PATCH /api/pleroma/admin/users/:nickname/toggle_activation", %{admin: admin, conn: conn} do
    user = insert(:user)

    conn = patch(conn, "/api/pleroma/admin/users/#{user.nickname}/toggle_activation")

    assert json_response(conn, 200) ==
             %{
               "deactivated" => !user.deactivated,
               "id" => user.id,
               "nickname" => user.nickname,
               "roles" => %{"admin" => false, "moderator" => false},
               "local" => true,
               "tags" => [],
               "avatar" => User.avatar_url(user) |> MediaProxy.url(),
               "display_name" => HTML.strip_tags(user.name || user.nickname),
               "confirmation_pending" => false
             }

    log_entry = Repo.one(ModerationLog)

    assert ModerationLog.get_log_entry_message(log_entry) ==
             "@#{admin.nickname} deactivated users: @#{user.nickname}"
  end

  describe "PUT disable_mfa" do
    test "returns 200 and disable 2fa", %{conn: conn} do
      user =
        insert(:user,
          multi_factor_authentication_settings: %MFA.Settings{
            enabled: true,
            totp: %MFA.Settings.TOTP{secret: "otp_secret", confirmed: true}
          }
        )

      response =
        conn
        |> put("/api/pleroma/admin/users/disable_mfa", %{nickname: user.nickname})
        |> json_response(200)

      assert response == user.nickname
      mfa_settings = refresh_record(user).multi_factor_authentication_settings

      refute mfa_settings.enabled
      refute mfa_settings.totp.confirmed
    end

    test "returns 404 if user not found", %{conn: conn} do
      response =
        conn
        |> put("/api/pleroma/admin/users/disable_mfa", %{nickname: "nickname"})
        |> json_response(404)

      assert response == %{"error" => "Not found"}
    end
  end

  describe "GET /api/pleroma/admin/restart" do
    setup do: clear_config(:configurable_from_database, true)

    test "pleroma restarts", %{conn: conn} do
      capture_log(fn ->
        assert conn |> get("/api/pleroma/admin/restart") |> json_response(200) == %{}
      end) =~ "pleroma restarted"

      refute Restarter.Pleroma.need_reboot?()
    end
  end

  test "need_reboot flag", %{conn: conn} do
    assert conn
           |> get("/api/pleroma/admin/need_reboot")
           |> json_response(200) == %{"need_reboot" => false}

    Restarter.Pleroma.need_reboot()

    assert conn
           |> get("/api/pleroma/admin/need_reboot")
           |> json_response(200) == %{"need_reboot" => true}

    on_exit(fn -> Restarter.Pleroma.refresh() end)
  end

  describe "GET /api/pleroma/admin/users/:nickname/statuses" do
    setup do
      user = insert(:user)

      date1 = (DateTime.to_unix(DateTime.utc_now()) + 2000) |> DateTime.from_unix!()
      date2 = (DateTime.to_unix(DateTime.utc_now()) + 1000) |> DateTime.from_unix!()
      date3 = (DateTime.to_unix(DateTime.utc_now()) + 3000) |> DateTime.from_unix!()

      insert(:note_activity, user: user, published: date1)
      insert(:note_activity, user: user, published: date2)
      insert(:note_activity, user: user, published: date3)

      %{user: user}
    end

    test "renders user's statuses", %{conn: conn, user: user} do
      conn = get(conn, "/api/pleroma/admin/users/#{user.nickname}/statuses")

      assert json_response(conn, 200) |> length() == 3
    end

    test "renders user's statuses with a limit", %{conn: conn, user: user} do
      conn = get(conn, "/api/pleroma/admin/users/#{user.nickname}/statuses?page_size=2")

      assert json_response(conn, 200) |> length() == 2
    end

    test "doesn't return private statuses by default", %{conn: conn, user: user} do
      {:ok, _private_status} = CommonAPI.post(user, %{status: "private", visibility: "private"})

      {:ok, _public_status} = CommonAPI.post(user, %{status: "public", visibility: "public"})

      conn = get(conn, "/api/pleroma/admin/users/#{user.nickname}/statuses")

      assert json_response(conn, 200) |> length() == 4
    end

    test "returns private statuses with godmode on", %{conn: conn, user: user} do
      {:ok, _private_status} = CommonAPI.post(user, %{status: "private", visibility: "private"})

      {:ok, _public_status} = CommonAPI.post(user, %{status: "public", visibility: "public"})

      conn = get(conn, "/api/pleroma/admin/users/#{user.nickname}/statuses?godmode=true")

      assert json_response(conn, 200) |> length() == 5
    end

    test "excludes reblogs by default", %{conn: conn, user: user} do
      other_user = insert(:user)
      {:ok, activity} = CommonAPI.post(user, %{status: "."})
      {:ok, %Activity{}} = CommonAPI.repeat(activity.id, other_user)

      conn_res = get(conn, "/api/pleroma/admin/users/#{other_user.nickname}/statuses")
      assert json_response(conn_res, 200) |> length() == 0

      conn_res =
        get(conn, "/api/pleroma/admin/users/#{other_user.nickname}/statuses?with_reblogs=true")

      assert json_response(conn_res, 200) |> length() == 1
    end
  end

  describe "GET /api/pleroma/admin/moderation_log" do
    setup do
      moderator = insert(:user, is_moderator: true)

      %{moderator: moderator}
    end

    test "returns the log", %{conn: conn, admin: admin} do
      Repo.insert(%ModerationLog{
        data: %{
          actor: %{
            "id" => admin.id,
            "nickname" => admin.nickname,
            "type" => "user"
          },
          action: "relay_follow",
          target: "https://example.org/relay"
        },
        inserted_at: NaiveDateTime.truncate(~N[2017-08-15 15:47:06.597036], :second)
      })

      Repo.insert(%ModerationLog{
        data: %{
          actor: %{
            "id" => admin.id,
            "nickname" => admin.nickname,
            "type" => "user"
          },
          action: "relay_unfollow",
          target: "https://example.org/relay"
        },
        inserted_at: NaiveDateTime.truncate(~N[2017-08-16 15:47:06.597036], :second)
      })

      conn = get(conn, "/api/pleroma/admin/moderation_log")

      response = json_response(conn, 200)
      [first_entry, second_entry] = response["items"]

      assert response["total"] == 2
      assert first_entry["data"]["action"] == "relay_unfollow"

      assert first_entry["message"] ==
               "@#{admin.nickname} unfollowed relay: https://example.org/relay"

      assert second_entry["data"]["action"] == "relay_follow"

      assert second_entry["message"] ==
               "@#{admin.nickname} followed relay: https://example.org/relay"
    end

    test "returns the log with pagination", %{conn: conn, admin: admin} do
      Repo.insert(%ModerationLog{
        data: %{
          actor: %{
            "id" => admin.id,
            "nickname" => admin.nickname,
            "type" => "user"
          },
          action: "relay_follow",
          target: "https://example.org/relay"
        },
        inserted_at: NaiveDateTime.truncate(~N[2017-08-15 15:47:06.597036], :second)
      })

      Repo.insert(%ModerationLog{
        data: %{
          actor: %{
            "id" => admin.id,
            "nickname" => admin.nickname,
            "type" => "user"
          },
          action: "relay_unfollow",
          target: "https://example.org/relay"
        },
        inserted_at: NaiveDateTime.truncate(~N[2017-08-16 15:47:06.597036], :second)
      })

      conn1 = get(conn, "/api/pleroma/admin/moderation_log?page_size=1&page=1")

      response1 = json_response(conn1, 200)
      [first_entry] = response1["items"]

      assert response1["total"] == 2
      assert response1["items"] |> length() == 1
      assert first_entry["data"]["action"] == "relay_unfollow"

      assert first_entry["message"] ==
               "@#{admin.nickname} unfollowed relay: https://example.org/relay"

      conn2 = get(conn, "/api/pleroma/admin/moderation_log?page_size=1&page=2")

      response2 = json_response(conn2, 200)
      [second_entry] = response2["items"]

      assert response2["total"] == 2
      assert response2["items"] |> length() == 1
      assert second_entry["data"]["action"] == "relay_follow"

      assert second_entry["message"] ==
               "@#{admin.nickname} followed relay: https://example.org/relay"
    end

    test "filters log by date", %{conn: conn, admin: admin} do
      first_date = "2017-08-15T15:47:06Z"
      second_date = "2017-08-20T15:47:06Z"

      Repo.insert(%ModerationLog{
        data: %{
          actor: %{
            "id" => admin.id,
            "nickname" => admin.nickname,
            "type" => "user"
          },
          action: "relay_follow",
          target: "https://example.org/relay"
        },
        inserted_at: NaiveDateTime.from_iso8601!(first_date)
      })

      Repo.insert(%ModerationLog{
        data: %{
          actor: %{
            "id" => admin.id,
            "nickname" => admin.nickname,
            "type" => "user"
          },
          action: "relay_unfollow",
          target: "https://example.org/relay"
        },
        inserted_at: NaiveDateTime.from_iso8601!(second_date)
      })

      conn1 =
        get(
          conn,
          "/api/pleroma/admin/moderation_log?start_date=#{second_date}"
        )

      response1 = json_response(conn1, 200)
      [first_entry] = response1["items"]

      assert response1["total"] == 1
      assert first_entry["data"]["action"] == "relay_unfollow"

      assert first_entry["message"] ==
               "@#{admin.nickname} unfollowed relay: https://example.org/relay"
    end

    test "returns log filtered by user", %{conn: conn, admin: admin, moderator: moderator} do
      Repo.insert(%ModerationLog{
        data: %{
          actor: %{
            "id" => admin.id,
            "nickname" => admin.nickname,
            "type" => "user"
          },
          action: "relay_follow",
          target: "https://example.org/relay"
        }
      })

      Repo.insert(%ModerationLog{
        data: %{
          actor: %{
            "id" => moderator.id,
            "nickname" => moderator.nickname,
            "type" => "user"
          },
          action: "relay_unfollow",
          target: "https://example.org/relay"
        }
      })

      conn1 = get(conn, "/api/pleroma/admin/moderation_log?user_id=#{moderator.id}")

      response1 = json_response(conn1, 200)
      [first_entry] = response1["items"]

      assert response1["total"] == 1
      assert get_in(first_entry, ["data", "actor", "id"]) == moderator.id
    end

    test "returns log filtered by search", %{conn: conn, moderator: moderator} do
      ModerationLog.insert_log(%{
        actor: moderator,
        action: "relay_follow",
        target: "https://example.org/relay"
      })

      ModerationLog.insert_log(%{
        actor: moderator,
        action: "relay_unfollow",
        target: "https://example.org/relay"
      })

      conn1 = get(conn, "/api/pleroma/admin/moderation_log?search=unfo")

      response1 = json_response(conn1, 200)
      [first_entry] = response1["items"]

      assert response1["total"] == 1

      assert get_in(first_entry, ["data", "message"]) ==
               "@#{moderator.nickname} unfollowed relay: https://example.org/relay"
    end
  end

  describe "GET /users/:nickname/credentials" do
    test "gets the user credentials", %{conn: conn} do
      user = insert(:user)
      conn = get(conn, "/api/pleroma/admin/users/#{user.nickname}/credentials")

      response = assert json_response(conn, 200)
      assert response["email"] == user.email
    end

    test "returns 403 if requested by a non-admin" do
      user = insert(:user)

      conn =
        build_conn()
        |> assign(:user, user)
        |> get("/api/pleroma/admin/users/#{user.nickname}/credentials")

      assert json_response(conn, :forbidden)
    end
  end

  describe "PATCH /users/:nickname/credentials" do
    setup do
      user = insert(:user)
      [user: user]
    end

    test "changes password and email", %{conn: conn, admin: admin, user: user} do
      assert user.password_reset_pending == false

      conn =
        patch(conn, "/api/pleroma/admin/users/#{user.nickname}/credentials", %{
          "password" => "new_password",
          "email" => "new_email@example.com",
          "name" => "new_name"
        })

      assert json_response(conn, 200) == %{"status" => "success"}

      ObanHelpers.perform_all()

      updated_user = User.get_by_id(user.id)

      assert updated_user.email == "new_email@example.com"
      assert updated_user.name == "new_name"
      assert updated_user.password_hash != user.password_hash
      assert updated_user.password_reset_pending == true

      [log_entry2, log_entry1] = ModerationLog |> Repo.all() |> Enum.sort()

      assert ModerationLog.get_log_entry_message(log_entry1) ==
               "@#{admin.nickname} updated users: @#{user.nickname}"

      assert ModerationLog.get_log_entry_message(log_entry2) ==
               "@#{admin.nickname} forced password reset for users: @#{user.nickname}"
    end

    test "returns 403 if requested by a non-admin", %{user: user} do
      conn =
        build_conn()
        |> assign(:user, user)
        |> patch("/api/pleroma/admin/users/#{user.nickname}/credentials", %{
          "password" => "new_password",
          "email" => "new_email@example.com",
          "name" => "new_name"
        })

      assert json_response(conn, :forbidden)
    end

    test "changes actor type from permitted list", %{conn: conn, user: user} do
      assert user.actor_type == "Person"

      assert patch(conn, "/api/pleroma/admin/users/#{user.nickname}/credentials", %{
               "actor_type" => "Service"
             })
             |> json_response(200) == %{"status" => "success"}

      updated_user = User.get_by_id(user.id)

      assert updated_user.actor_type == "Service"

      assert patch(conn, "/api/pleroma/admin/users/#{user.nickname}/credentials", %{
               "actor_type" => "Application"
             })
             |> json_response(200) == %{"errors" => %{"actor_type" => "is invalid"}}
    end

    test "update non existing user", %{conn: conn} do
      assert patch(conn, "/api/pleroma/admin/users/non-existing/credentials", %{
               "password" => "new_password"
             })
             |> json_response(200) == %{"error" => "Unable to update user."}
    end
  end

  describe "PATCH /users/:nickname/force_password_reset" do
    test "sets password_reset_pending to true", %{conn: conn} do
      user = insert(:user)
      assert user.password_reset_pending == false

      conn =
        patch(conn, "/api/pleroma/admin/users/force_password_reset", %{nicknames: [user.nickname]})

      assert json_response(conn, 204) == ""

      ObanHelpers.perform_all()

      assert User.get_by_id(user.id).password_reset_pending == true
    end
  end

  describe "instances" do
    test "GET /instances/:instance/statuses", %{conn: conn} do
      user = insert(:user, local: false, nickname: "archaeme@archae.me")
      user2 = insert(:user, local: false, nickname: "test@test.com")
      insert_pair(:note_activity, user: user)
      activity = insert(:note_activity, user: user2)

      ret_conn = get(conn, "/api/pleroma/admin/instances/archae.me/statuses")

      response = json_response(ret_conn, 200)

      assert length(response) == 2

      ret_conn = get(conn, "/api/pleroma/admin/instances/test.com/statuses")

      response = json_response(ret_conn, 200)

      assert length(response) == 1

      ret_conn = get(conn, "/api/pleroma/admin/instances/nonexistent.com/statuses")

      response = json_response(ret_conn, 200)

      assert Enum.empty?(response)

      CommonAPI.repeat(activity.id, user)

      ret_conn = get(conn, "/api/pleroma/admin/instances/archae.me/statuses")
      response = json_response(ret_conn, 200)
      assert length(response) == 2

      ret_conn = get(conn, "/api/pleroma/admin/instances/archae.me/statuses?with_reblogs=true")
      response = json_response(ret_conn, 200)
      assert length(response) == 3
    end
  end

  describe "PATCH /confirm_email" do
    test "it confirms emails of two users", %{conn: conn, admin: admin} do
      [first_user, second_user] = insert_pair(:user, confirmation_pending: true)

      assert first_user.confirmation_pending == true
      assert second_user.confirmation_pending == true

      ret_conn =
        patch(conn, "/api/pleroma/admin/users/confirm_email", %{
          nicknames: [
            first_user.nickname,
            second_user.nickname
          ]
        })

      assert ret_conn.status == 200

      assert first_user.confirmation_pending == true
      assert second_user.confirmation_pending == true

      log_entry = Repo.one(ModerationLog)

      assert ModerationLog.get_log_entry_message(log_entry) ==
               "@#{admin.nickname} confirmed email for users: @#{first_user.nickname}, @#{
                 second_user.nickname
               }"
    end
  end

  describe "PATCH /resend_confirmation_email" do
    test "it resend emails for two users", %{conn: conn, admin: admin} do
      [first_user, second_user] = insert_pair(:user, confirmation_pending: true)

      ret_conn =
        patch(conn, "/api/pleroma/admin/users/resend_confirmation_email", %{
          nicknames: [
            first_user.nickname,
            second_user.nickname
          ]
        })

      assert ret_conn.status == 200

      log_entry = Repo.one(ModerationLog)

      assert ModerationLog.get_log_entry_message(log_entry) ==
               "@#{admin.nickname} re-sent confirmation email for users: @#{first_user.nickname}, @#{
                 second_user.nickname
               }"
    end
  end

  describe "/api/pleroma/admin/stats" do
    test "status visibility count", %{conn: conn} do
      admin = insert(:user, is_admin: true)
      user = insert(:user)
      CommonAPI.post(user, %{visibility: "public", status: "hey"})
      CommonAPI.post(user, %{visibility: "unlisted", status: "hey"})
      CommonAPI.post(user, %{visibility: "unlisted", status: "hey"})

      response =
        conn
        |> assign(:user, admin)
        |> get("/api/pleroma/admin/stats")
        |> json_response(200)

      assert %{"direct" => 0, "private" => 0, "public" => 1, "unlisted" => 2} =
               response["status_visibility"]
    end
  end
end

# Needed for testing
defmodule Pleroma.Web.Endpoint.NotReal do
end

defmodule Pleroma.Captcha.NotReal do
end
