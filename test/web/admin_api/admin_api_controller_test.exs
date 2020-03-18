# Pleroma: A lightweight social networking server
# Copyright © 2017-2020 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.AdminAPI.AdminAPIControllerTest do
  use Pleroma.Web.ConnCase
  use Oban.Testing, repo: Pleroma.Repo

  import Pleroma.Factory
  import ExUnit.CaptureLog

  alias Pleroma.Activity
  alias Pleroma.Config
  alias Pleroma.ConfigDB
  alias Pleroma.HTML
  alias Pleroma.ModerationLog
  alias Pleroma.Repo
  alias Pleroma.ReportNote
  alias Pleroma.Tests.ObanHelpers
  alias Pleroma.User
  alias Pleroma.UserInviteToken
  alias Pleroma.Web.ActivityPub.Relay
  alias Pleroma.Web.CommonAPI
  alias Pleroma.Web.MastodonAPI.StatusView
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
    clear_config([:auth, :enforce_oauth_admin_scope_usage], true)

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
    clear_config([:auth, :enforce_oauth_admin_scope_usage], false)

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

      conn =
        conn
        |> put_req_header("accept", "application/json")
        |> delete("/api/pleroma/admin/users?nickname=#{user.nickname}")

      log_entry = Repo.one(ModerationLog)

      assert ModerationLog.get_log_entry_message(log_entry) ==
               "@#{admin.nickname} deleted users: @#{user.nickname}"

      assert json_response(conn, 200) == user.nickname
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

      assert "Not found" == json_response(conn, 404)
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

  describe "POST /api/pleroma/admin/email_invite, with valid config" do
    clear_config([:instance, :registrations_open], false)
    clear_config([:instance, :invites_enabled], true)

    test "sends invitation and returns 204", %{admin: admin, conn: conn} do
      recipient_email = "foo@bar.com"
      recipient_name = "J. D."

      conn =
        post(
          conn,
          "/api/pleroma/admin/users/email_invite?email=#{recipient_email}&name=#{recipient_name}"
        )

      assert json_response(conn, :no_content)

      token_record = List.last(Repo.all(Pleroma.UserInviteToken))
      assert token_record
      refute token_record.used

      notify_email = Config.get([:instance, :notify_email])
      instance_name = Config.get([:instance, :name])

      email =
        Pleroma.Emails.UserEmail.user_invitation_email(
          admin,
          token_record,
          recipient_email,
          recipient_name
        )

      Swoosh.TestAssertions.assert_email_sent(
        from: {instance_name, notify_email},
        to: {recipient_name, recipient_email},
        html_body: email.html_body
      )
    end

    test "it returns 403 if requested by a non-admin" do
      non_admin_user = insert(:user)
      token = insert(:oauth_token, user: non_admin_user)

      conn =
        build_conn()
        |> assign(:user, non_admin_user)
        |> assign(:token, token)
        |> post("/api/pleroma/admin/users/email_invite?email=foo@bar.com&name=JD")

      assert json_response(conn, :forbidden)
    end
  end

  describe "POST /api/pleroma/admin/users/email_invite, with invalid config" do
    clear_config([:instance, :registrations_open])
    clear_config([:instance, :invites_enabled])

    test "it returns 500 if `invites_enabled` is not enabled", %{conn: conn} do
      Config.put([:instance, :registrations_open], false)
      Config.put([:instance, :invites_enabled], false)

      conn = post(conn, "/api/pleroma/admin/users/email_invite?email=foo@bar.com&name=JD")

      assert json_response(conn, :internal_server_error)
    end

    test "it returns 500 if `registrations_open` is enabled", %{conn: conn} do
      Config.put([:instance, :registrations_open], true)
      Config.put([:instance, :invites_enabled], true)

      conn = post(conn, "/api/pleroma/admin/users/email_invite?email=foo@bar.com&name=JD")

      assert json_response(conn, :internal_server_error)
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

  describe "POST /api/pleroma/admin/users/invite_token" do
    test "without options", %{conn: conn} do
      conn = post(conn, "/api/pleroma/admin/users/invite_token")

      invite_json = json_response(conn, 200)
      invite = UserInviteToken.find_by_token!(invite_json["token"])
      refute invite.used
      refute invite.expires_at
      refute invite.max_use
      assert invite.invite_type == "one_time"
    end

    test "with expires_at", %{conn: conn} do
      conn =
        post(conn, "/api/pleroma/admin/users/invite_token", %{
          "expires_at" => Date.to_string(Date.utc_today())
        })

      invite_json = json_response(conn, 200)
      invite = UserInviteToken.find_by_token!(invite_json["token"])

      refute invite.used
      assert invite.expires_at == Date.utc_today()
      refute invite.max_use
      assert invite.invite_type == "date_limited"
    end

    test "with max_use", %{conn: conn} do
      conn = post(conn, "/api/pleroma/admin/users/invite_token", %{"max_use" => 150})

      invite_json = json_response(conn, 200)
      invite = UserInviteToken.find_by_token!(invite_json["token"])
      refute invite.used
      refute invite.expires_at
      assert invite.max_use == 150
      assert invite.invite_type == "reusable"
    end

    test "with max use and expires_at", %{conn: conn} do
      conn =
        post(conn, "/api/pleroma/admin/users/invite_token", %{
          "max_use" => 150,
          "expires_at" => Date.to_string(Date.utc_today())
        })

      invite_json = json_response(conn, 200)
      invite = UserInviteToken.find_by_token!(invite_json["token"])
      refute invite.used
      assert invite.expires_at == Date.utc_today()
      assert invite.max_use == 150
      assert invite.invite_type == "reusable_date_limited"
    end
  end

  describe "GET /api/pleroma/admin/users/invites" do
    test "no invites", %{conn: conn} do
      conn = get(conn, "/api/pleroma/admin/users/invites")

      assert json_response(conn, 200) == %{"invites" => []}
    end

    test "with invite", %{conn: conn} do
      {:ok, invite} = UserInviteToken.create_invite()

      conn = get(conn, "/api/pleroma/admin/users/invites")

      assert json_response(conn, 200) == %{
               "invites" => [
                 %{
                   "expires_at" => nil,
                   "id" => invite.id,
                   "invite_type" => "one_time",
                   "max_use" => nil,
                   "token" => invite.token,
                   "used" => false,
                   "uses" => 0
                 }
               ]
             }
    end
  end

  describe "POST /api/pleroma/admin/users/revoke_invite" do
    test "with token", %{conn: conn} do
      {:ok, invite} = UserInviteToken.create_invite()

      conn = post(conn, "/api/pleroma/admin/users/revoke_invite", %{"token" => invite.token})

      assert json_response(conn, 200) == %{
               "expires_at" => nil,
               "id" => invite.id,
               "invite_type" => "one_time",
               "max_use" => nil,
               "token" => invite.token,
               "used" => true,
               "uses" => 0
             }
    end

    test "with invalid token", %{conn: conn} do
      conn = post(conn, "/api/pleroma/admin/users/revoke_invite", %{"token" => "foo"})

      assert json_response(conn, :not_found) == "Not found"
    end
  end

  describe "GET /api/pleroma/admin/reports/:id" do
    test "returns report by its id", %{conn: conn} do
      [reporter, target_user] = insert_pair(:user)
      activity = insert(:note_activity, user: target_user)

      {:ok, %{id: report_id}} =
        CommonAPI.report(reporter, %{
          "account_id" => target_user.id,
          "comment" => "I feel offended",
          "status_ids" => [activity.id]
        })

      response =
        conn
        |> get("/api/pleroma/admin/reports/#{report_id}")
        |> json_response(:ok)

      assert response["id"] == report_id
    end

    test "returns 404 when report id is invalid", %{conn: conn} do
      conn = get(conn, "/api/pleroma/admin/reports/test")

      assert json_response(conn, :not_found) == "Not found"
    end
  end

  describe "PATCH /api/pleroma/admin/reports" do
    setup do
      [reporter, target_user] = insert_pair(:user)
      activity = insert(:note_activity, user: target_user)

      {:ok, %{id: report_id}} =
        CommonAPI.report(reporter, %{
          "account_id" => target_user.id,
          "comment" => "I feel offended",
          "status_ids" => [activity.id]
        })

      {:ok, %{id: second_report_id}} =
        CommonAPI.report(reporter, %{
          "account_id" => target_user.id,
          "comment" => "I feel very offended",
          "status_ids" => [activity.id]
        })

      %{
        id: report_id,
        second_report_id: second_report_id
      }
    end

    test "requires admin:write:reports scope", %{conn: conn, id: id, admin: admin} do
      read_token = insert(:oauth_token, user: admin, scopes: ["admin:read"])
      write_token = insert(:oauth_token, user: admin, scopes: ["admin:write:reports"])

      response =
        conn
        |> assign(:token, read_token)
        |> patch("/api/pleroma/admin/reports", %{
          "reports" => [%{"state" => "resolved", "id" => id}]
        })
        |> json_response(403)

      assert response == %{
               "error" => "Insufficient permissions: admin:write:reports."
             }

      conn
      |> assign(:token, write_token)
      |> patch("/api/pleroma/admin/reports", %{
        "reports" => [%{"state" => "resolved", "id" => id}]
      })
      |> json_response(:no_content)
    end

    test "mark report as resolved", %{conn: conn, id: id, admin: admin} do
      conn
      |> patch("/api/pleroma/admin/reports", %{
        "reports" => [
          %{"state" => "resolved", "id" => id}
        ]
      })
      |> json_response(:no_content)

      activity = Activity.get_by_id(id)
      assert activity.data["state"] == "resolved"

      log_entry = Repo.one(ModerationLog)

      assert ModerationLog.get_log_entry_message(log_entry) ==
               "@#{admin.nickname} updated report ##{id} with 'resolved' state"
    end

    test "closes report", %{conn: conn, id: id, admin: admin} do
      conn
      |> patch("/api/pleroma/admin/reports", %{
        "reports" => [
          %{"state" => "closed", "id" => id}
        ]
      })
      |> json_response(:no_content)

      activity = Activity.get_by_id(id)
      assert activity.data["state"] == "closed"

      log_entry = Repo.one(ModerationLog)

      assert ModerationLog.get_log_entry_message(log_entry) ==
               "@#{admin.nickname} updated report ##{id} with 'closed' state"
    end

    test "returns 400 when state is unknown", %{conn: conn, id: id} do
      conn =
        conn
        |> patch("/api/pleroma/admin/reports", %{
          "reports" => [
            %{"state" => "test", "id" => id}
          ]
        })

      assert hd(json_response(conn, :bad_request))["error"] == "Unsupported state"
    end

    test "returns 404 when report is not exist", %{conn: conn} do
      conn =
        conn
        |> patch("/api/pleroma/admin/reports", %{
          "reports" => [
            %{"state" => "closed", "id" => "test"}
          ]
        })

      assert hd(json_response(conn, :bad_request))["error"] == "not_found"
    end

    test "updates state of multiple reports", %{
      conn: conn,
      id: id,
      admin: admin,
      second_report_id: second_report_id
    } do
      conn
      |> patch("/api/pleroma/admin/reports", %{
        "reports" => [
          %{"state" => "resolved", "id" => id},
          %{"state" => "closed", "id" => second_report_id}
        ]
      })
      |> json_response(:no_content)

      activity = Activity.get_by_id(id)
      second_activity = Activity.get_by_id(second_report_id)
      assert activity.data["state"] == "resolved"
      assert second_activity.data["state"] == "closed"

      [first_log_entry, second_log_entry] = Repo.all(ModerationLog)

      assert ModerationLog.get_log_entry_message(first_log_entry) ==
               "@#{admin.nickname} updated report ##{id} with 'resolved' state"

      assert ModerationLog.get_log_entry_message(second_log_entry) ==
               "@#{admin.nickname} updated report ##{second_report_id} with 'closed' state"
    end
  end

  describe "GET /api/pleroma/admin/reports" do
    test "returns empty response when no reports created", %{conn: conn} do
      response =
        conn
        |> get("/api/pleroma/admin/reports")
        |> json_response(:ok)

      assert Enum.empty?(response["reports"])
      assert response["total"] == 0
    end

    test "returns reports", %{conn: conn} do
      [reporter, target_user] = insert_pair(:user)
      activity = insert(:note_activity, user: target_user)

      {:ok, %{id: report_id}} =
        CommonAPI.report(reporter, %{
          "account_id" => target_user.id,
          "comment" => "I feel offended",
          "status_ids" => [activity.id]
        })

      response =
        conn
        |> get("/api/pleroma/admin/reports")
        |> json_response(:ok)

      [report] = response["reports"]

      assert length(response["reports"]) == 1
      assert report["id"] == report_id

      assert response["total"] == 1
    end

    test "returns reports with specified state", %{conn: conn} do
      [reporter, target_user] = insert_pair(:user)
      activity = insert(:note_activity, user: target_user)

      {:ok, %{id: first_report_id}} =
        CommonAPI.report(reporter, %{
          "account_id" => target_user.id,
          "comment" => "I feel offended",
          "status_ids" => [activity.id]
        })

      {:ok, %{id: second_report_id}} =
        CommonAPI.report(reporter, %{
          "account_id" => target_user.id,
          "comment" => "I don't like this user"
        })

      CommonAPI.update_report_state(second_report_id, "closed")

      response =
        conn
        |> get("/api/pleroma/admin/reports", %{
          "state" => "open"
        })
        |> json_response(:ok)

      [open_report] = response["reports"]

      assert length(response["reports"]) == 1
      assert open_report["id"] == first_report_id

      assert response["total"] == 1

      response =
        conn
        |> get("/api/pleroma/admin/reports", %{
          "state" => "closed"
        })
        |> json_response(:ok)

      [closed_report] = response["reports"]

      assert length(response["reports"]) == 1
      assert closed_report["id"] == second_report_id

      assert response["total"] == 1

      response =
        conn
        |> get("/api/pleroma/admin/reports", %{
          "state" => "resolved"
        })
        |> json_response(:ok)

      assert Enum.empty?(response["reports"])
      assert response["total"] == 0
    end

    test "returns 403 when requested by a non-admin" do
      user = insert(:user)
      token = insert(:oauth_token, user: user)

      conn =
        build_conn()
        |> assign(:user, user)
        |> assign(:token, token)
        |> get("/api/pleroma/admin/reports")

      assert json_response(conn, :forbidden) ==
               %{"error" => "User is not an admin or OAuth admin scope is not granted."}
    end

    test "returns 403 when requested by anonymous" do
      conn = get(build_conn(), "/api/pleroma/admin/reports")

      assert json_response(conn, :forbidden) == %{"error" => "Invalid credentials."}
    end
  end

  describe "GET /api/pleroma/admin/grouped_reports" do
    setup do
      [reporter, target_user] = insert_pair(:user)

      date1 = (DateTime.to_unix(DateTime.utc_now()) + 1000) |> DateTime.from_unix!()
      date2 = (DateTime.to_unix(DateTime.utc_now()) + 2000) |> DateTime.from_unix!()
      date3 = (DateTime.to_unix(DateTime.utc_now()) + 3000) |> DateTime.from_unix!()

      first_status =
        insert(:note_activity, user: target_user, data_attrs: %{"published" => date1})

      second_status =
        insert(:note_activity, user: target_user, data_attrs: %{"published" => date2})

      third_status =
        insert(:note_activity, user: target_user, data_attrs: %{"published" => date3})

      {:ok, first_report} =
        CommonAPI.report(reporter, %{
          "account_id" => target_user.id,
          "status_ids" => [first_status.id, second_status.id, third_status.id]
        })

      {:ok, second_report} =
        CommonAPI.report(reporter, %{
          "account_id" => target_user.id,
          "status_ids" => [first_status.id, second_status.id]
        })

      {:ok, third_report} =
        CommonAPI.report(reporter, %{
          "account_id" => target_user.id,
          "status_ids" => [first_status.id]
        })

      %{
        first_status: Activity.get_by_ap_id_with_object(first_status.data["id"]),
        second_status: Activity.get_by_ap_id_with_object(second_status.data["id"]),
        third_status: Activity.get_by_ap_id_with_object(third_status.data["id"]),
        first_report: first_report,
        first_status_reports: [first_report, second_report, third_report],
        second_status_reports: [first_report, second_report],
        third_status_reports: [first_report],
        target_user: target_user,
        reporter: reporter
      }
    end

    test "returns reports grouped by status", %{
      conn: conn,
      first_status: first_status,
      second_status: second_status,
      third_status: third_status,
      first_status_reports: first_status_reports,
      second_status_reports: second_status_reports,
      third_status_reports: third_status_reports,
      target_user: target_user,
      reporter: reporter
    } do
      response =
        conn
        |> get("/api/pleroma/admin/grouped_reports")
        |> json_response(:ok)

      assert length(response["reports"]) == 3

      first_group = Enum.find(response["reports"], &(&1["status"]["id"] == first_status.id))

      second_group = Enum.find(response["reports"], &(&1["status"]["id"] == second_status.id))

      third_group = Enum.find(response["reports"], &(&1["status"]["id"] == third_status.id))

      assert length(first_group["reports"]) == 3
      assert length(second_group["reports"]) == 2
      assert length(third_group["reports"]) == 1

      assert first_group["date"] ==
               Enum.max_by(first_status_reports, fn act ->
                 NaiveDateTime.from_iso8601!(act.data["published"])
               end).data["published"]

      assert first_group["status"] ==
               Map.put(
                 stringify_keys(StatusView.render("show.json", %{activity: first_status})),
                 "deleted",
                 false
               )

      assert(first_group["account"]["id"] == target_user.id)

      assert length(first_group["actors"]) == 1
      assert hd(first_group["actors"])["id"] == reporter.id

      assert Enum.map(first_group["reports"], & &1["id"]) --
               Enum.map(first_status_reports, & &1.id) == []

      assert second_group["date"] ==
               Enum.max_by(second_status_reports, fn act ->
                 NaiveDateTime.from_iso8601!(act.data["published"])
               end).data["published"]

      assert second_group["status"] ==
               Map.put(
                 stringify_keys(StatusView.render("show.json", %{activity: second_status})),
                 "deleted",
                 false
               )

      assert second_group["account"]["id"] == target_user.id

      assert length(second_group["actors"]) == 1
      assert hd(second_group["actors"])["id"] == reporter.id

      assert Enum.map(second_group["reports"], & &1["id"]) --
               Enum.map(second_status_reports, & &1.id) == []

      assert third_group["date"] ==
               Enum.max_by(third_status_reports, fn act ->
                 NaiveDateTime.from_iso8601!(act.data["published"])
               end).data["published"]

      assert third_group["status"] ==
               Map.put(
                 stringify_keys(StatusView.render("show.json", %{activity: third_status})),
                 "deleted",
                 false
               )

      assert third_group["account"]["id"] == target_user.id

      assert length(third_group["actors"]) == 1
      assert hd(third_group["actors"])["id"] == reporter.id

      assert Enum.map(third_group["reports"], & &1["id"]) --
               Enum.map(third_status_reports, & &1.id) == []
    end

    test "reopened report renders status data", %{
      conn: conn,
      first_report: first_report,
      first_status: first_status
    } do
      {:ok, _} = CommonAPI.update_report_state(first_report.id, "resolved")

      response =
        conn
        |> get("/api/pleroma/admin/grouped_reports")
        |> json_response(:ok)

      first_group = Enum.find(response["reports"], &(&1["status"]["id"] == first_status.id))

      assert first_group["status"] ==
               Map.put(
                 stringify_keys(StatusView.render("show.json", %{activity: first_status})),
                 "deleted",
                 false
               )
    end

    test "reopened report does not render status data if status has been deleted", %{
      conn: conn,
      first_report: first_report,
      first_status: first_status,
      target_user: target_user
    } do
      {:ok, _} = CommonAPI.update_report_state(first_report.id, "resolved")
      {:ok, _} = CommonAPI.delete(first_status.id, target_user)

      refute Activity.get_by_ap_id(first_status.id)

      response =
        conn
        |> get("/api/pleroma/admin/grouped_reports")
        |> json_response(:ok)

      assert Enum.find(response["reports"], &(&1["status"]["deleted"] == true))["status"][
               "deleted"
             ] == true

      assert length(Enum.filter(response["reports"], &(&1["status"]["deleted"] == false))) == 2
    end

    test "account not empty if status was deleted", %{
      conn: conn,
      first_report: first_report,
      first_status: first_status,
      target_user: target_user
    } do
      {:ok, _} = CommonAPI.update_report_state(first_report.id, "resolved")
      {:ok, _} = CommonAPI.delete(first_status.id, target_user)

      refute Activity.get_by_ap_id(first_status.id)

      response =
        conn
        |> get("/api/pleroma/admin/grouped_reports")
        |> json_response(:ok)

      assert Enum.find(response["reports"], &(&1["status"]["deleted"] == true))["account"]
    end
  end

  describe "PUT /api/pleroma/admin/statuses/:id" do
    setup do
      activity = insert(:note_activity)

      %{id: activity.id}
    end

    test "toggle sensitive flag", %{conn: conn, id: id, admin: admin} do
      response =
        conn
        |> put("/api/pleroma/admin/statuses/#{id}", %{"sensitive" => "true"})
        |> json_response(:ok)

      assert response["sensitive"]

      log_entry = Repo.one(ModerationLog)

      assert ModerationLog.get_log_entry_message(log_entry) ==
               "@#{admin.nickname} updated status ##{id}, set sensitive: 'true'"

      response =
        conn
        |> put("/api/pleroma/admin/statuses/#{id}", %{"sensitive" => "false"})
        |> json_response(:ok)

      refute response["sensitive"]
    end

    test "change visibility flag", %{conn: conn, id: id, admin: admin} do
      response =
        conn
        |> put("/api/pleroma/admin/statuses/#{id}", %{"visibility" => "public"})
        |> json_response(:ok)

      assert response["visibility"] == "public"

      log_entry = Repo.one(ModerationLog)

      assert ModerationLog.get_log_entry_message(log_entry) ==
               "@#{admin.nickname} updated status ##{id}, set visibility: 'public'"

      response =
        conn
        |> put("/api/pleroma/admin/statuses/#{id}", %{"visibility" => "private"})
        |> json_response(:ok)

      assert response["visibility"] == "private"

      response =
        conn
        |> put("/api/pleroma/admin/statuses/#{id}", %{"visibility" => "unlisted"})
        |> json_response(:ok)

      assert response["visibility"] == "unlisted"
    end

    test "returns 400 when visibility is unknown", %{conn: conn, id: id} do
      conn = put(conn, "/api/pleroma/admin/statuses/#{id}", %{"visibility" => "test"})

      assert json_response(conn, :bad_request) == "Unsupported visibility"
    end
  end

  describe "DELETE /api/pleroma/admin/statuses/:id" do
    setup do
      activity = insert(:note_activity)

      %{id: activity.id}
    end

    test "deletes status", %{conn: conn, id: id, admin: admin} do
      conn
      |> delete("/api/pleroma/admin/statuses/#{id}")
      |> json_response(:ok)

      refute Activity.get_by_id(id)

      log_entry = Repo.one(ModerationLog)

      assert ModerationLog.get_log_entry_message(log_entry) ==
               "@#{admin.nickname} deleted status ##{id}"
    end

    test "returns 404 when the status does not exist", %{conn: conn} do
      conn = delete(conn, "/api/pleroma/admin/statuses/test")

      assert json_response(conn, :not_found) == "Not found"
    end
  end

  describe "GET /api/pleroma/admin/config" do
    clear_config(:configurable_from_database, true)

    test "when configuration from database is off", %{conn: conn} do
      Config.put(:configurable_from_database, false)
      conn = get(conn, "/api/pleroma/admin/config")

      assert json_response(conn, 400) ==
               "To use this endpoint you need to enable configuration from database."
    end

    test "with settings only in db", %{conn: conn} do
      config1 = insert(:config)
      config2 = insert(:config)

      conn = get(conn, "/api/pleroma/admin/config", %{"only_db" => true})

      %{
        "configs" => [
          %{
            "group" => ":pleroma",
            "key" => key1,
            "value" => _
          },
          %{
            "group" => ":pleroma",
            "key" => key2,
            "value" => _
          }
        ]
      } = json_response(conn, 200)

      assert key1 == config1.key
      assert key2 == config2.key
    end

    test "db is added to settings that are in db", %{conn: conn} do
      _config = insert(:config, key: ":instance", value: ConfigDB.to_binary(name: "Some name"))

      %{"configs" => configs} =
        conn
        |> get("/api/pleroma/admin/config")
        |> json_response(200)

      [instance_config] =
        Enum.filter(configs, fn %{"group" => group, "key" => key} ->
          group == ":pleroma" and key == ":instance"
        end)

      assert instance_config["db"] == [":name"]
    end

    test "merged default setting with db settings", %{conn: conn} do
      config1 = insert(:config)
      config2 = insert(:config)

      config3 =
        insert(:config,
          value: ConfigDB.to_binary(k1: :v1, k2: :v2)
        )

      %{"configs" => configs} =
        conn
        |> get("/api/pleroma/admin/config")
        |> json_response(200)

      assert length(configs) > 3

      received_configs =
        Enum.filter(configs, fn %{"group" => group, "key" => key} ->
          group == ":pleroma" and key in [config1.key, config2.key, config3.key]
        end)

      assert length(received_configs) == 3

      db_keys =
        config3.value
        |> ConfigDB.from_binary()
        |> Keyword.keys()
        |> ConfigDB.convert()

      Enum.each(received_configs, fn %{"value" => value, "db" => db} ->
        assert db in [[config1.key], [config2.key], db_keys]

        assert value in [
                 ConfigDB.from_binary_with_convert(config1.value),
                 ConfigDB.from_binary_with_convert(config2.value),
                 ConfigDB.from_binary_with_convert(config3.value)
               ]
      end)
    end

    test "subkeys with full update right merge", %{conn: conn} do
      config1 =
        insert(:config,
          key: ":emoji",
          value: ConfigDB.to_binary(groups: [a: 1, b: 2], key: [a: 1])
        )

      config2 =
        insert(:config,
          key: ":assets",
          value: ConfigDB.to_binary(mascots: [a: 1, b: 2], key: [a: 1])
        )

      %{"configs" => configs} =
        conn
        |> get("/api/pleroma/admin/config")
        |> json_response(200)

      vals =
        Enum.filter(configs, fn %{"group" => group, "key" => key} ->
          group == ":pleroma" and key in [config1.key, config2.key]
        end)

      emoji = Enum.find(vals, fn %{"key" => key} -> key == ":emoji" end)
      assets = Enum.find(vals, fn %{"key" => key} -> key == ":assets" end)

      emoji_val = ConfigDB.transform_with_out_binary(emoji["value"])
      assets_val = ConfigDB.transform_with_out_binary(assets["value"])

      assert emoji_val[:groups] == [a: 1, b: 2]
      assert assets_val[:mascots] == [a: 1, b: 2]
    end
  end

  test "POST /api/pleroma/admin/config error", %{conn: conn} do
    conn = post(conn, "/api/pleroma/admin/config", %{"configs" => []})

    assert json_response(conn, 400) ==
             "To use this endpoint you need to enable configuration from database."
  end

  describe "POST /api/pleroma/admin/config" do
    setup do
      http = Application.get_env(:pleroma, :http)

      on_exit(fn ->
        Application.delete_env(:pleroma, :key1)
        Application.delete_env(:pleroma, :key2)
        Application.delete_env(:pleroma, :key3)
        Application.delete_env(:pleroma, :key4)
        Application.delete_env(:pleroma, :keyaa1)
        Application.delete_env(:pleroma, :keyaa2)
        Application.delete_env(:pleroma, Pleroma.Web.Endpoint.NotReal)
        Application.delete_env(:pleroma, Pleroma.Captcha.NotReal)
        Application.put_env(:pleroma, :http, http)
        Application.put_env(:tesla, :adapter, Tesla.Mock)
        Restarter.Pleroma.refresh()
      end)
    end

    clear_config(:configurable_from_database, true)

    @tag capture_log: true
    test "create new config setting in db", %{conn: conn} do
      ueberauth = Application.get_env(:ueberauth, Ueberauth)
      on_exit(fn -> Application.put_env(:ueberauth, Ueberauth, ueberauth) end)

      conn =
        post(conn, "/api/pleroma/admin/config", %{
          configs: [
            %{group: ":pleroma", key: ":key1", value: "value1"},
            %{
              group: ":ueberauth",
              key: "Ueberauth",
              value: [%{"tuple" => [":consumer_secret", "aaaa"]}]
            },
            %{
              group: ":pleroma",
              key: ":key2",
              value: %{
                ":nested_1" => "nested_value1",
                ":nested_2" => [
                  %{":nested_22" => "nested_value222"},
                  %{":nested_33" => %{":nested_44" => "nested_444"}}
                ]
              }
            },
            %{
              group: ":pleroma",
              key: ":key3",
              value: [
                %{"nested_3" => ":nested_3", "nested_33" => "nested_33"},
                %{"nested_4" => true}
              ]
            },
            %{
              group: ":pleroma",
              key: ":key4",
              value: %{":nested_5" => ":upload", "endpoint" => "https://example.com"}
            },
            %{
              group: ":idna",
              key: ":key5",
              value: %{"tuple" => ["string", "Pleroma.Captcha.NotReal", []]}
            }
          ]
        })

      assert json_response(conn, 200) == %{
               "configs" => [
                 %{
                   "group" => ":pleroma",
                   "key" => ":key1",
                   "value" => "value1",
                   "db" => [":key1"]
                 },
                 %{
                   "group" => ":ueberauth",
                   "key" => "Ueberauth",
                   "value" => [%{"tuple" => [":consumer_secret", "aaaa"]}],
                   "db" => [":consumer_secret"]
                 },
                 %{
                   "group" => ":pleroma",
                   "key" => ":key2",
                   "value" => %{
                     ":nested_1" => "nested_value1",
                     ":nested_2" => [
                       %{":nested_22" => "nested_value222"},
                       %{":nested_33" => %{":nested_44" => "nested_444"}}
                     ]
                   },
                   "db" => [":key2"]
                 },
                 %{
                   "group" => ":pleroma",
                   "key" => ":key3",
                   "value" => [
                     %{"nested_3" => ":nested_3", "nested_33" => "nested_33"},
                     %{"nested_4" => true}
                   ],
                   "db" => [":key3"]
                 },
                 %{
                   "group" => ":pleroma",
                   "key" => ":key4",
                   "value" => %{"endpoint" => "https://example.com", ":nested_5" => ":upload"},
                   "db" => [":key4"]
                 },
                 %{
                   "group" => ":idna",
                   "key" => ":key5",
                   "value" => %{"tuple" => ["string", "Pleroma.Captcha.NotReal", []]},
                   "db" => [":key5"]
                 }
               ]
             }

      assert Application.get_env(:pleroma, :key1) == "value1"

      assert Application.get_env(:pleroma, :key2) == %{
               nested_1: "nested_value1",
               nested_2: [
                 %{nested_22: "nested_value222"},
                 %{nested_33: %{nested_44: "nested_444"}}
               ]
             }

      assert Application.get_env(:pleroma, :key3) == [
               %{"nested_3" => :nested_3, "nested_33" => "nested_33"},
               %{"nested_4" => true}
             ]

      assert Application.get_env(:pleroma, :key4) == %{
               "endpoint" => "https://example.com",
               nested_5: :upload
             }

      assert Application.get_env(:idna, :key5) == {"string", Pleroma.Captcha.NotReal, []}
    end

    test "save configs setting without explicit key", %{conn: conn} do
      level = Application.get_env(:quack, :level)
      meta = Application.get_env(:quack, :meta)
      webhook_url = Application.get_env(:quack, :webhook_url)

      on_exit(fn ->
        Application.put_env(:quack, :level, level)
        Application.put_env(:quack, :meta, meta)
        Application.put_env(:quack, :webhook_url, webhook_url)
      end)

      conn =
        post(conn, "/api/pleroma/admin/config", %{
          configs: [
            %{
              group: ":quack",
              key: ":level",
              value: ":info"
            },
            %{
              group: ":quack",
              key: ":meta",
              value: [":none"]
            },
            %{
              group: ":quack",
              key: ":webhook_url",
              value: "https://hooks.slack.com/services/KEY"
            }
          ]
        })

      assert json_response(conn, 200) == %{
               "configs" => [
                 %{
                   "group" => ":quack",
                   "key" => ":level",
                   "value" => ":info",
                   "db" => [":level"]
                 },
                 %{
                   "group" => ":quack",
                   "key" => ":meta",
                   "value" => [":none"],
                   "db" => [":meta"]
                 },
                 %{
                   "group" => ":quack",
                   "key" => ":webhook_url",
                   "value" => "https://hooks.slack.com/services/KEY",
                   "db" => [":webhook_url"]
                 }
               ]
             }

      assert Application.get_env(:quack, :level) == :info
      assert Application.get_env(:quack, :meta) == [:none]
      assert Application.get_env(:quack, :webhook_url) == "https://hooks.slack.com/services/KEY"
    end

    test "saving config with partial update", %{conn: conn} do
      config = insert(:config, key: ":key1", value: :erlang.term_to_binary(key1: 1, key2: 2))

      conn =
        post(conn, "/api/pleroma/admin/config", %{
          configs: [
            %{group: config.group, key: config.key, value: [%{"tuple" => [":key3", 3]}]}
          ]
        })

      assert json_response(conn, 200) == %{
               "configs" => [
                 %{
                   "group" => ":pleroma",
                   "key" => ":key1",
                   "value" => [
                     %{"tuple" => [":key1", 1]},
                     %{"tuple" => [":key2", 2]},
                     %{"tuple" => [":key3", 3]}
                   ],
                   "db" => [":key1", ":key2", ":key3"]
                 }
               ]
             }
    end

    test "saving config which need pleroma reboot", %{conn: conn} do
      chat = Config.get(:chat)
      on_exit(fn -> Config.put(:chat, chat) end)

      assert post(
               conn,
               "/api/pleroma/admin/config",
               %{
                 configs: [
                   %{group: ":pleroma", key: ":chat", value: [%{"tuple" => [":enabled", true]}]}
                 ]
               }
             )
             |> json_response(200) == %{
               "configs" => [
                 %{
                   "db" => [":enabled"],
                   "group" => ":pleroma",
                   "key" => ":chat",
                   "value" => [%{"tuple" => [":enabled", true]}]
                 }
               ],
               "need_reboot" => true
             }

      configs =
        conn
        |> get("/api/pleroma/admin/config")
        |> json_response(200)

      assert configs["need_reboot"]

      capture_log(fn ->
        assert conn |> get("/api/pleroma/admin/restart") |> json_response(200) == %{}
      end) =~ "pleroma restarted"

      configs =
        conn
        |> get("/api/pleroma/admin/config")
        |> json_response(200)

      refute Map.has_key?(configs, "need_reboot")
    end

    test "update setting which need reboot, don't change reboot flag until reboot", %{conn: conn} do
      chat = Config.get(:chat)
      on_exit(fn -> Config.put(:chat, chat) end)

      assert post(
               conn,
               "/api/pleroma/admin/config",
               %{
                 configs: [
                   %{group: ":pleroma", key: ":chat", value: [%{"tuple" => [":enabled", true]}]}
                 ]
               }
             )
             |> json_response(200) == %{
               "configs" => [
                 %{
                   "db" => [":enabled"],
                   "group" => ":pleroma",
                   "key" => ":chat",
                   "value" => [%{"tuple" => [":enabled", true]}]
                 }
               ],
               "need_reboot" => true
             }

      assert post(conn, "/api/pleroma/admin/config", %{
               configs: [
                 %{group: ":pleroma", key: ":key1", value: [%{"tuple" => [":key3", 3]}]}
               ]
             })
             |> json_response(200) == %{
               "configs" => [
                 %{
                   "group" => ":pleroma",
                   "key" => ":key1",
                   "value" => [
                     %{"tuple" => [":key3", 3]}
                   ],
                   "db" => [":key3"]
                 }
               ],
               "need_reboot" => true
             }

      capture_log(fn ->
        assert conn |> get("/api/pleroma/admin/restart") |> json_response(200) == %{}
      end) =~ "pleroma restarted"

      configs =
        conn
        |> get("/api/pleroma/admin/config")
        |> json_response(200)

      refute Map.has_key?(configs, "need_reboot")
    end

    test "saving config with nested merge", %{conn: conn} do
      config =
        insert(:config, key: ":key1", value: :erlang.term_to_binary(key1: 1, key2: [k1: 1, k2: 2]))

      conn =
        post(conn, "/api/pleroma/admin/config", %{
          configs: [
            %{
              group: config.group,
              key: config.key,
              value: [
                %{"tuple" => [":key3", 3]},
                %{
                  "tuple" => [
                    ":key2",
                    [
                      %{"tuple" => [":k2", 1]},
                      %{"tuple" => [":k3", 3]}
                    ]
                  ]
                }
              ]
            }
          ]
        })

      assert json_response(conn, 200) == %{
               "configs" => [
                 %{
                   "group" => ":pleroma",
                   "key" => ":key1",
                   "value" => [
                     %{"tuple" => [":key1", 1]},
                     %{"tuple" => [":key3", 3]},
                     %{
                       "tuple" => [
                         ":key2",
                         [
                           %{"tuple" => [":k1", 1]},
                           %{"tuple" => [":k2", 1]},
                           %{"tuple" => [":k3", 3]}
                         ]
                       ]
                     }
                   ],
                   "db" => [":key1", ":key3", ":key2"]
                 }
               ]
             }
    end

    test "saving special atoms", %{conn: conn} do
      conn =
        post(conn, "/api/pleroma/admin/config", %{
          "configs" => [
            %{
              "group" => ":pleroma",
              "key" => ":key1",
              "value" => [
                %{
                  "tuple" => [
                    ":ssl_options",
                    [%{"tuple" => [":versions", [":tlsv1", ":tlsv1.1", ":tlsv1.2"]]}]
                  ]
                }
              ]
            }
          ]
        })

      assert json_response(conn, 200) == %{
               "configs" => [
                 %{
                   "group" => ":pleroma",
                   "key" => ":key1",
                   "value" => [
                     %{
                       "tuple" => [
                         ":ssl_options",
                         [%{"tuple" => [":versions", [":tlsv1", ":tlsv1.1", ":tlsv1.2"]]}]
                       ]
                     }
                   ],
                   "db" => [":ssl_options"]
                 }
               ]
             }

      assert Application.get_env(:pleroma, :key1) == [
               ssl_options: [versions: [:tlsv1, :"tlsv1.1", :"tlsv1.2"]]
             ]
    end

    test "saving full setting if value is in full_key_update list", %{conn: conn} do
      backends = Application.get_env(:logger, :backends)
      on_exit(fn -> Application.put_env(:logger, :backends, backends) end)

      config =
        insert(:config,
          group: ":logger",
          key: ":backends",
          value: :erlang.term_to_binary([])
        )

      conn =
        post(conn, "/api/pleroma/admin/config", %{
          configs: [
            %{
              group: config.group,
              key: config.key,
              value: [":console", %{"tuple" => ["ExSyslogger", ":ex_syslogger"]}]
            }
          ]
        })

      assert json_response(conn, 200) == %{
               "configs" => [
                 %{
                   "group" => ":logger",
                   "key" => ":backends",
                   "value" => [
                     ":console",
                     %{"tuple" => ["ExSyslogger", ":ex_syslogger"]}
                   ],
                   "db" => [":backends"]
                 }
               ]
             }

      assert Application.get_env(:logger, :backends) == [
               :console,
               {ExSyslogger, :ex_syslogger}
             ]

      capture_log(fn ->
        require Logger
        Logger.warn("Ooops...")
      end) =~ "Ooops..."
    end

    test "saving full setting if value is not keyword", %{conn: conn} do
      config =
        insert(:config,
          group: ":tesla",
          key: ":adapter",
          value: :erlang.term_to_binary(Tesla.Adapter.Hackey)
        )

      conn =
        post(conn, "/api/pleroma/admin/config", %{
          configs: [
            %{group: config.group, key: config.key, value: "Tesla.Adapter.Httpc"}
          ]
        })

      assert json_response(conn, 200) == %{
               "configs" => [
                 %{
                   "group" => ":tesla",
                   "key" => ":adapter",
                   "value" => "Tesla.Adapter.Httpc",
                   "db" => [":adapter"]
                 }
               ]
             }
    end

    test "update config setting & delete with fallback to default value", %{
      conn: conn,
      admin: admin,
      token: token
    } do
      ueberauth = Application.get_env(:ueberauth, Ueberauth)
      config1 = insert(:config, key: ":keyaa1")
      config2 = insert(:config, key: ":keyaa2")

      config3 =
        insert(:config,
          group: ":ueberauth",
          key: "Ueberauth"
        )

      conn =
        post(conn, "/api/pleroma/admin/config", %{
          configs: [
            %{group: config1.group, key: config1.key, value: "another_value"},
            %{group: config2.group, key: config2.key, value: "another_value"}
          ]
        })

      assert json_response(conn, 200) == %{
               "configs" => [
                 %{
                   "group" => ":pleroma",
                   "key" => config1.key,
                   "value" => "another_value",
                   "db" => [":keyaa1"]
                 },
                 %{
                   "group" => ":pleroma",
                   "key" => config2.key,
                   "value" => "another_value",
                   "db" => [":keyaa2"]
                 }
               ]
             }

      assert Application.get_env(:pleroma, :keyaa1) == "another_value"
      assert Application.get_env(:pleroma, :keyaa2) == "another_value"
      assert Application.get_env(:ueberauth, Ueberauth) == ConfigDB.from_binary(config3.value)

      conn =
        build_conn()
        |> assign(:user, admin)
        |> assign(:token, token)
        |> post("/api/pleroma/admin/config", %{
          configs: [
            %{group: config2.group, key: config2.key, delete: true},
            %{
              group: ":ueberauth",
              key: "Ueberauth",
              delete: true
            }
          ]
        })

      assert json_response(conn, 200) == %{
               "configs" => []
             }

      assert Application.get_env(:ueberauth, Ueberauth) == ueberauth
      refute Keyword.has_key?(Application.get_all_env(:pleroma), :keyaa2)
    end

    test "common config example", %{conn: conn} do
      adapter = Application.get_env(:tesla, :adapter)
      on_exit(fn -> Application.put_env(:tesla, :adapter, adapter) end)

      conn =
        post(conn, "/api/pleroma/admin/config", %{
          configs: [
            %{
              "group" => ":pleroma",
              "key" => "Pleroma.Captcha.NotReal",
              "value" => [
                %{"tuple" => [":enabled", false]},
                %{"tuple" => [":method", "Pleroma.Captcha.Kocaptcha"]},
                %{"tuple" => [":seconds_valid", 60]},
                %{"tuple" => [":path", ""]},
                %{"tuple" => [":key1", nil]},
                %{"tuple" => [":partial_chain", "&:hackney_connect.partial_chain/1"]},
                %{"tuple" => [":regex1", "~r/https:\/\/example.com/"]},
                %{"tuple" => [":regex2", "~r/https:\/\/example.com/u"]},
                %{"tuple" => [":regex3", "~r/https:\/\/example.com/i"]},
                %{"tuple" => [":regex4", "~r/https:\/\/example.com/s"]},
                %{"tuple" => [":name", "Pleroma"]}
              ]
            },
            %{
              "group" => ":tesla",
              "key" => ":adapter",
              "value" => "Tesla.Adapter.Httpc"
            }
          ]
        })

      assert Application.get_env(:tesla, :adapter) == Tesla.Adapter.Httpc
      assert Config.get([Pleroma.Captcha.NotReal, :name]) == "Pleroma"

      assert json_response(conn, 200) == %{
               "configs" => [
                 %{
                   "group" => ":pleroma",
                   "key" => "Pleroma.Captcha.NotReal",
                   "value" => [
                     %{"tuple" => [":enabled", false]},
                     %{"tuple" => [":method", "Pleroma.Captcha.Kocaptcha"]},
                     %{"tuple" => [":seconds_valid", 60]},
                     %{"tuple" => [":path", ""]},
                     %{"tuple" => [":key1", nil]},
                     %{"tuple" => [":partial_chain", "&:hackney_connect.partial_chain/1"]},
                     %{"tuple" => [":regex1", "~r/https:\\/\\/example.com/"]},
                     %{"tuple" => [":regex2", "~r/https:\\/\\/example.com/u"]},
                     %{"tuple" => [":regex3", "~r/https:\\/\\/example.com/i"]},
                     %{"tuple" => [":regex4", "~r/https:\\/\\/example.com/s"]},
                     %{"tuple" => [":name", "Pleroma"]}
                   ],
                   "db" => [
                     ":enabled",
                     ":method",
                     ":seconds_valid",
                     ":path",
                     ":key1",
                     ":partial_chain",
                     ":regex1",
                     ":regex2",
                     ":regex3",
                     ":regex4",
                     ":name"
                   ]
                 },
                 %{
                   "group" => ":tesla",
                   "key" => ":adapter",
                   "value" => "Tesla.Adapter.Httpc",
                   "db" => [":adapter"]
                 }
               ]
             }
    end

    test "tuples with more than two values", %{conn: conn} do
      conn =
        post(conn, "/api/pleroma/admin/config", %{
          configs: [
            %{
              "group" => ":pleroma",
              "key" => "Pleroma.Web.Endpoint.NotReal",
              "value" => [
                %{
                  "tuple" => [
                    ":http",
                    [
                      %{
                        "tuple" => [
                          ":key2",
                          [
                            %{
                              "tuple" => [
                                ":_",
                                [
                                  %{
                                    "tuple" => [
                                      "/api/v1/streaming",
                                      "Pleroma.Web.MastodonAPI.WebsocketHandler",
                                      []
                                    ]
                                  },
                                  %{
                                    "tuple" => [
                                      "/websocket",
                                      "Phoenix.Endpoint.CowboyWebSocket",
                                      %{
                                        "tuple" => [
                                          "Phoenix.Transports.WebSocket",
                                          %{
                                            "tuple" => [
                                              "Pleroma.Web.Endpoint",
                                              "Pleroma.Web.UserSocket",
                                              []
                                            ]
                                          }
                                        ]
                                      }
                                    ]
                                  },
                                  %{
                                    "tuple" => [
                                      ":_",
                                      "Phoenix.Endpoint.Cowboy2Handler",
                                      %{"tuple" => ["Pleroma.Web.Endpoint", []]}
                                    ]
                                  }
                                ]
                              ]
                            }
                          ]
                        ]
                      }
                    ]
                  ]
                }
              ]
            }
          ]
        })

      assert json_response(conn, 200) == %{
               "configs" => [
                 %{
                   "group" => ":pleroma",
                   "key" => "Pleroma.Web.Endpoint.NotReal",
                   "value" => [
                     %{
                       "tuple" => [
                         ":http",
                         [
                           %{
                             "tuple" => [
                               ":key2",
                               [
                                 %{
                                   "tuple" => [
                                     ":_",
                                     [
                                       %{
                                         "tuple" => [
                                           "/api/v1/streaming",
                                           "Pleroma.Web.MastodonAPI.WebsocketHandler",
                                           []
                                         ]
                                       },
                                       %{
                                         "tuple" => [
                                           "/websocket",
                                           "Phoenix.Endpoint.CowboyWebSocket",
                                           %{
                                             "tuple" => [
                                               "Phoenix.Transports.WebSocket",
                                               %{
                                                 "tuple" => [
                                                   "Pleroma.Web.Endpoint",
                                                   "Pleroma.Web.UserSocket",
                                                   []
                                                 ]
                                               }
                                             ]
                                           }
                                         ]
                                       },
                                       %{
                                         "tuple" => [
                                           ":_",
                                           "Phoenix.Endpoint.Cowboy2Handler",
                                           %{"tuple" => ["Pleroma.Web.Endpoint", []]}
                                         ]
                                       }
                                     ]
                                   ]
                                 }
                               ]
                             ]
                           }
                         ]
                       ]
                     }
                   ],
                   "db" => [":http"]
                 }
               ]
             }
    end

    test "settings with nesting map", %{conn: conn} do
      conn =
        post(conn, "/api/pleroma/admin/config", %{
          configs: [
            %{
              "group" => ":pleroma",
              "key" => ":key1",
              "value" => [
                %{"tuple" => [":key2", "some_val"]},
                %{
                  "tuple" => [
                    ":key3",
                    %{
                      ":max_options" => 20,
                      ":max_option_chars" => 200,
                      ":min_expiration" => 0,
                      ":max_expiration" => 31_536_000,
                      "nested" => %{
                        ":max_options" => 20,
                        ":max_option_chars" => 200,
                        ":min_expiration" => 0,
                        ":max_expiration" => 31_536_000
                      }
                    }
                  ]
                }
              ]
            }
          ]
        })

      assert json_response(conn, 200) ==
               %{
                 "configs" => [
                   %{
                     "group" => ":pleroma",
                     "key" => ":key1",
                     "value" => [
                       %{"tuple" => [":key2", "some_val"]},
                       %{
                         "tuple" => [
                           ":key3",
                           %{
                             ":max_expiration" => 31_536_000,
                             ":max_option_chars" => 200,
                             ":max_options" => 20,
                             ":min_expiration" => 0,
                             "nested" => %{
                               ":max_expiration" => 31_536_000,
                               ":max_option_chars" => 200,
                               ":max_options" => 20,
                               ":min_expiration" => 0
                             }
                           }
                         ]
                       }
                     ],
                     "db" => [":key2", ":key3"]
                   }
                 ]
               }
    end

    test "value as map", %{conn: conn} do
      conn =
        post(conn, "/api/pleroma/admin/config", %{
          configs: [
            %{
              "group" => ":pleroma",
              "key" => ":key1",
              "value" => %{"key" => "some_val"}
            }
          ]
        })

      assert json_response(conn, 200) ==
               %{
                 "configs" => [
                   %{
                     "group" => ":pleroma",
                     "key" => ":key1",
                     "value" => %{"key" => "some_val"},
                     "db" => [":key1"]
                   }
                 ]
               }
    end

    test "queues key as atom", %{conn: conn} do
      conn =
        post(conn, "/api/pleroma/admin/config", %{
          configs: [
            %{
              "group" => ":oban",
              "key" => ":queues",
              "value" => [
                %{"tuple" => [":federator_incoming", 50]},
                %{"tuple" => [":federator_outgoing", 50]},
                %{"tuple" => [":web_push", 50]},
                %{"tuple" => [":mailer", 10]},
                %{"tuple" => [":transmogrifier", 20]},
                %{"tuple" => [":scheduled_activities", 10]},
                %{"tuple" => [":background", 5]}
              ]
            }
          ]
        })

      assert json_response(conn, 200) == %{
               "configs" => [
                 %{
                   "group" => ":oban",
                   "key" => ":queues",
                   "value" => [
                     %{"tuple" => [":federator_incoming", 50]},
                     %{"tuple" => [":federator_outgoing", 50]},
                     %{"tuple" => [":web_push", 50]},
                     %{"tuple" => [":mailer", 10]},
                     %{"tuple" => [":transmogrifier", 20]},
                     %{"tuple" => [":scheduled_activities", 10]},
                     %{"tuple" => [":background", 5]}
                   ],
                   "db" => [
                     ":federator_incoming",
                     ":federator_outgoing",
                     ":web_push",
                     ":mailer",
                     ":transmogrifier",
                     ":scheduled_activities",
                     ":background"
                   ]
                 }
               ]
             }
    end

    test "delete part of settings by atom subkeys", %{conn: conn} do
      config =
        insert(:config,
          key: ":keyaa1",
          value: :erlang.term_to_binary(subkey1: "val1", subkey2: "val2", subkey3: "val3")
        )

      conn =
        post(conn, "/api/pleroma/admin/config", %{
          configs: [
            %{
              group: config.group,
              key: config.key,
              subkeys: [":subkey1", ":subkey3"],
              delete: true
            }
          ]
        })

      assert json_response(conn, 200) == %{
               "configs" => [
                 %{
                   "group" => ":pleroma",
                   "key" => ":keyaa1",
                   "value" => [%{"tuple" => [":subkey2", "val2"]}],
                   "db" => [":subkey2"]
                 }
               ]
             }
    end

    test "proxy tuple localhost", %{conn: conn} do
      conn =
        post(conn, "/api/pleroma/admin/config", %{
          configs: [
            %{
              group: ":pleroma",
              key: ":http",
              value: [
                %{"tuple" => [":proxy_url", %{"tuple" => [":socks5", "localhost", 1234]}]},
                %{"tuple" => [":send_user_agent", false]}
              ]
            }
          ]
        })

      assert json_response(conn, 200) == %{
               "configs" => [
                 %{
                   "group" => ":pleroma",
                   "key" => ":http",
                   "value" => [
                     %{"tuple" => [":proxy_url", %{"tuple" => [":socks5", "localhost", 1234]}]},
                     %{"tuple" => [":send_user_agent", false]}
                   ],
                   "db" => [":proxy_url", ":send_user_agent"]
                 }
               ]
             }
    end

    test "proxy tuple domain", %{conn: conn} do
      conn =
        post(conn, "/api/pleroma/admin/config", %{
          configs: [
            %{
              group: ":pleroma",
              key: ":http",
              value: [
                %{"tuple" => [":proxy_url", %{"tuple" => [":socks5", "domain.com", 1234]}]},
                %{"tuple" => [":send_user_agent", false]}
              ]
            }
          ]
        })

      assert json_response(conn, 200) == %{
               "configs" => [
                 %{
                   "group" => ":pleroma",
                   "key" => ":http",
                   "value" => [
                     %{"tuple" => [":proxy_url", %{"tuple" => [":socks5", "domain.com", 1234]}]},
                     %{"tuple" => [":send_user_agent", false]}
                   ],
                   "db" => [":proxy_url", ":send_user_agent"]
                 }
               ]
             }
    end

    test "proxy tuple ip", %{conn: conn} do
      conn =
        post(conn, "/api/pleroma/admin/config", %{
          configs: [
            %{
              group: ":pleroma",
              key: ":http",
              value: [
                %{"tuple" => [":proxy_url", %{"tuple" => [":socks5", "127.0.0.1", 1234]}]},
                %{"tuple" => [":send_user_agent", false]}
              ]
            }
          ]
        })

      assert json_response(conn, 200) == %{
               "configs" => [
                 %{
                   "group" => ":pleroma",
                   "key" => ":http",
                   "value" => [
                     %{"tuple" => [":proxy_url", %{"tuple" => [":socks5", "127.0.0.1", 1234]}]},
                     %{"tuple" => [":send_user_agent", false]}
                   ],
                   "db" => [":proxy_url", ":send_user_agent"]
                 }
               ]
             }
    end
  end

  describe "GET /api/pleroma/admin/restart" do
    clear_config(:configurable_from_database, true)

    test "pleroma restarts", %{conn: conn} do
      capture_log(fn ->
        assert conn |> get("/api/pleroma/admin/restart") |> json_response(200) == %{}
      end) =~ "pleroma restarted"

      refute Restarter.Pleroma.need_reboot?()
    end
  end

  describe "GET /api/pleroma/admin/statuses" do
    test "returns all public and unlisted statuses", %{conn: conn, admin: admin} do
      blocked = insert(:user)
      user = insert(:user)
      User.block(admin, blocked)

      {:ok, _} =
        CommonAPI.post(user, %{"status" => "@#{admin.nickname}", "visibility" => "direct"})

      {:ok, _} = CommonAPI.post(user, %{"status" => ".", "visibility" => "unlisted"})
      {:ok, _} = CommonAPI.post(user, %{"status" => ".", "visibility" => "private"})
      {:ok, _} = CommonAPI.post(user, %{"status" => ".", "visibility" => "public"})
      {:ok, _} = CommonAPI.post(blocked, %{"status" => ".", "visibility" => "public"})

      response =
        conn
        |> get("/api/pleroma/admin/statuses")
        |> json_response(200)

      refute "private" in Enum.map(response, & &1["visibility"])
      assert length(response) == 3
    end

    test "returns only local statuses with local_only on", %{conn: conn} do
      user = insert(:user)
      remote_user = insert(:user, local: false, nickname: "archaeme@archae.me")
      insert(:note_activity, user: user, local: true)
      insert(:note_activity, user: remote_user, local: false)

      response =
        conn
        |> get("/api/pleroma/admin/statuses?local_only=true")
        |> json_response(200)

      assert length(response) == 1
    end

    test "returns private and direct statuses with godmode on", %{conn: conn, admin: admin} do
      user = insert(:user)

      {:ok, _} =
        CommonAPI.post(user, %{"status" => "@#{admin.nickname}", "visibility" => "direct"})

      {:ok, _} = CommonAPI.post(user, %{"status" => ".", "visibility" => "private"})
      {:ok, _} = CommonAPI.post(user, %{"status" => ".", "visibility" => "public"})
      conn = get(conn, "/api/pleroma/admin/statuses?godmode=true")
      assert json_response(conn, 200) |> length() == 3
    end
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
      {:ok, _private_status} =
        CommonAPI.post(user, %{"status" => "private", "visibility" => "private"})

      {:ok, _public_status} =
        CommonAPI.post(user, %{"status" => "public", "visibility" => "public"})

      conn = get(conn, "/api/pleroma/admin/users/#{user.nickname}/statuses")

      assert json_response(conn, 200) |> length() == 4
    end

    test "returns private statuses with godmode on", %{conn: conn, user: user} do
      {:ok, _private_status} =
        CommonAPI.post(user, %{"status" => "private", "visibility" => "private"})

      {:ok, _public_status} =
        CommonAPI.post(user, %{"status" => "public", "visibility" => "public"})

      conn = get(conn, "/api/pleroma/admin/users/#{user.nickname}/statuses?godmode=true")

      assert json_response(conn, 200) |> length() == 5
    end

    test "excludes reblogs by default", %{conn: conn, user: user} do
      other_user = insert(:user)
      {:ok, activity} = CommonAPI.post(user, %{"status" => "."})
      {:ok, %Activity{}, _} = CommonAPI.repeat(activity.id, other_user)

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

  describe "relays" do
    test "POST /relay", %{conn: conn, admin: admin} do
      conn =
        post(conn, "/api/pleroma/admin/relay", %{
          relay_url: "http://mastodon.example.org/users/admin"
        })

      assert json_response(conn, 200) == "http://mastodon.example.org/users/admin"

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

      assert json_response(conn, 200)["relays"] -- ["mastodon.example.org", "mstdn.io"] == []
    end

    test "DELETE /relay", %{conn: conn, admin: admin} do
      post(conn, "/api/pleroma/admin/relay", %{
        relay_url: "http://mastodon.example.org/users/admin"
      })

      conn =
        delete(conn, "/api/pleroma/admin/relay", %{
          relay_url: "http://mastodon.example.org/users/admin"
        })

      assert json_response(conn, 200) == "http://mastodon.example.org/users/admin"

      [log_entry_one, log_entry_two] = Repo.all(ModerationLog)

      assert ModerationLog.get_log_entry_message(log_entry_one) ==
               "@#{admin.nickname} followed relay: http://mastodon.example.org/users/admin"

      assert ModerationLog.get_log_entry_message(log_entry_two) ==
               "@#{admin.nickname} unfollowed relay: http://mastodon.example.org/users/admin"
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

  describe "POST /reports/:id/notes" do
    setup %{conn: conn, admin: admin} do
      [reporter, target_user] = insert_pair(:user)
      activity = insert(:note_activity, user: target_user)

      {:ok, %{id: report_id}} =
        CommonAPI.report(reporter, %{
          "account_id" => target_user.id,
          "comment" => "I feel offended",
          "status_ids" => [activity.id]
        })

      post(conn, "/api/pleroma/admin/reports/#{report_id}/notes", %{
        content: "this is disgusting!"
      })

      post(conn, "/api/pleroma/admin/reports/#{report_id}/notes", %{
        content: "this is disgusting2!"
      })

      %{
        admin_id: admin.id,
        report_id: report_id
      }
    end

    test "it creates report note", %{admin_id: admin_id, report_id: report_id} do
      [note, _] = Repo.all(ReportNote)

      assert %{
               activity_id: ^report_id,
               content: "this is disgusting!",
               user_id: ^admin_id
             } = note
    end

    test "it returns reports with notes", %{conn: conn, admin: admin} do
      conn = get(conn, "/api/pleroma/admin/reports")

      response = json_response(conn, 200)
      notes = hd(response["reports"])["notes"]
      [note, _] = notes

      assert note["user"]["nickname"] == admin.nickname
      assert note["content"] == "this is disgusting!"
      assert note["created_at"]
      assert response["total"] == 1
    end

    test "it deletes the note", %{conn: conn, report_id: report_id} do
      assert ReportNote |> Repo.all() |> length() == 2

      [note, _] = Repo.all(ReportNote)

      delete(conn, "/api/pleroma/admin/reports/#{report_id}/notes/#{note.id}")

      assert ReportNote |> Repo.all() |> length() == 1
    end
  end

  test "GET /api/pleroma/admin/config/descriptions", %{conn: conn} do
    admin = insert(:user, is_admin: true)

    conn =
      assign(conn, :user, admin)
      |> get("/api/pleroma/admin/config/descriptions")

    assert [child | _others] = json_response(conn, 200)

    assert child["children"]
    assert child["key"]
    assert String.starts_with?(child["group"], ":")
    assert child["description"]
  end

  describe "/api/pleroma/admin/stats" do
    test "status visibility count", %{conn: conn} do
      admin = insert(:user, is_admin: true)
      user = insert(:user)
      CommonAPI.post(user, %{"visibility" => "public", "status" => "hey"})
      CommonAPI.post(user, %{"visibility" => "unlisted", "status" => "hey"})
      CommonAPI.post(user, %{"visibility" => "unlisted", "status" => "hey"})

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
