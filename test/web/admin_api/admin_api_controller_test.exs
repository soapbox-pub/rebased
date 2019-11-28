# Pleroma: A lightweight social networking server
# Copyright © 2017-2019 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.AdminAPI.AdminAPIControllerTest do
  use Pleroma.Web.ConnCase
  use Oban.Testing, repo: Pleroma.Repo

  alias Pleroma.Activity
  alias Pleroma.HTML
  alias Pleroma.ModerationLog
  alias Pleroma.Repo
  alias Pleroma.Tests.ObanHelpers
  alias Pleroma.User
  alias Pleroma.UserInviteToken
  alias Pleroma.Web.ActivityPub.Relay
  alias Pleroma.Web.CommonAPI
  alias Pleroma.Web.MediaProxy
  import Pleroma.Factory

  setup_all do
    Tesla.Mock.mock_global(fn env -> apply(HttpRequestMock, :request, [env]) end)

    :ok
  end

  describe "DELETE /api/pleroma/admin/users" do
    test "single user" do
      admin = insert(:user, is_admin: true)
      user = insert(:user)

      conn =
        build_conn()
        |> assign(:user, admin)
        |> put_req_header("accept", "application/json")
        |> delete("/api/pleroma/admin/users?nickname=#{user.nickname}")

      log_entry = Repo.one(ModerationLog)

      assert ModerationLog.get_log_entry_message(log_entry) ==
               "@#{admin.nickname} deleted users: @#{user.nickname}"

      assert json_response(conn, 200) == user.nickname
    end

    test "multiple users" do
      admin = insert(:user, is_admin: true)
      user_one = insert(:user)
      user_two = insert(:user)

      conn =
        build_conn()
        |> assign(:user, admin)
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
    test "Create" do
      admin = insert(:user, is_admin: true)

      conn =
        build_conn()
        |> assign(:user, admin)
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

    test "Cannot create user with exisiting email" do
      admin = insert(:user, is_admin: true)
      user = insert(:user)

      conn =
        build_conn()
        |> assign(:user, admin)
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

    test "Cannot create user with exisiting nickname" do
      admin = insert(:user, is_admin: true)
      user = insert(:user)

      conn =
        build_conn()
        |> assign(:user, admin)
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

    test "Multiple user creation works in transaction" do
      admin = insert(:user, is_admin: true)
      user = insert(:user)

      conn =
        build_conn()
        |> assign(:user, admin)
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
      admin = insert(:user, is_admin: true)
      user = insert(:user)

      conn =
        conn
        |> assign(:user, admin)
        |> get("/api/pleroma/admin/users/#{user.nickname}")

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
      admin = insert(:user, is_admin: true)
      user = build(:user)

      conn =
        conn
        |> assign(:user, admin)
        |> get("/api/pleroma/admin/users/#{user.nickname}")

      assert "Not found" == json_response(conn, 404)
    end
  end

  describe "/api/pleroma/admin/users/follow" do
    test "allows to force-follow another user" do
      admin = insert(:user, is_admin: true)
      user = insert(:user)
      follower = insert(:user)

      build_conn()
      |> assign(:user, admin)
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
    test "allows to force-unfollow another user" do
      admin = insert(:user, is_admin: true)
      user = insert(:user)
      follower = insert(:user)

      User.follow(follower, user)

      build_conn()
      |> assign(:user, admin)
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
    setup do
      admin = insert(:user, is_admin: true)
      user1 = insert(:user, %{tags: ["x"]})
      user2 = insert(:user, %{tags: ["y"]})
      user3 = insert(:user, %{tags: ["unchanged"]})

      conn =
        build_conn()
        |> assign(:user, admin)
        |> put_req_header("accept", "application/json")
        |> put(
          "/api/pleroma/admin/users/tag?nicknames[]=#{user1.nickname}&nicknames[]=#{
            user2.nickname
          }&tags[]=foo&tags[]=bar"
        )

      %{conn: conn, admin: admin, user1: user1, user2: user2, user3: user3}
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
    setup do
      admin = insert(:user, is_admin: true)
      user1 = insert(:user, %{tags: ["x"]})
      user2 = insert(:user, %{tags: ["y", "z"]})
      user3 = insert(:user, %{tags: ["unchanged"]})

      conn =
        build_conn()
        |> assign(:user, admin)
        |> put_req_header("accept", "application/json")
        |> delete(
          "/api/pleroma/admin/users/tag?nicknames[]=#{user1.nickname}&nicknames[]=#{
            user2.nickname
          }&tags[]=x&tags[]=z"
        )

      %{conn: conn, admin: admin, user1: user1, user2: user2, user3: user3}
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
    test "GET is giving user_info" do
      admin = insert(:user, is_admin: true)

      conn =
        build_conn()
        |> assign(:user, admin)
        |> put_req_header("accept", "application/json")
        |> get("/api/pleroma/admin/users/#{admin.nickname}/permission_group/")

      assert json_response(conn, 200) == %{
               "is_admin" => true,
               "is_moderator" => false
             }
    end

    test "/:right POST, can add to a permission group" do
      admin = insert(:user, is_admin: true)
      user = insert(:user)

      conn =
        build_conn()
        |> assign(:user, admin)
        |> put_req_header("accept", "application/json")
        |> post("/api/pleroma/admin/users/#{user.nickname}/permission_group/admin")

      assert json_response(conn, 200) == %{
               "is_admin" => true
             }

      log_entry = Repo.one(ModerationLog)

      assert ModerationLog.get_log_entry_message(log_entry) ==
               "@#{admin.nickname} made @#{user.nickname} admin"
    end

    test "/:right POST, can add to a permission group (multiple)" do
      admin = insert(:user, is_admin: true)
      user_one = insert(:user)
      user_two = insert(:user)

      conn =
        build_conn()
        |> assign(:user, admin)
        |> put_req_header("accept", "application/json")
        |> post("/api/pleroma/admin/users/permission_group/admin", %{
          nicknames: [user_one.nickname, user_two.nickname]
        })

      assert json_response(conn, 200) == %{
               "is_admin" => true
             }

      log_entry = Repo.one(ModerationLog)

      assert ModerationLog.get_log_entry_message(log_entry) ==
               "@#{admin.nickname} made @#{user_one.nickname}, @#{user_two.nickname} admin"
    end

    test "/:right DELETE, can remove from a permission group" do
      admin = insert(:user, is_admin: true)
      user = insert(:user, is_admin: true)

      conn =
        build_conn()
        |> assign(:user, admin)
        |> put_req_header("accept", "application/json")
        |> delete("/api/pleroma/admin/users/#{user.nickname}/permission_group/admin")

      assert json_response(conn, 200) == %{
               "is_admin" => false
             }

      log_entry = Repo.one(ModerationLog)

      assert ModerationLog.get_log_entry_message(log_entry) ==
               "@#{admin.nickname} revoked admin role from @#{user.nickname}"
    end

    test "/:right DELETE, can remove from a permission group (multiple)" do
      admin = insert(:user, is_admin: true)
      user_one = insert(:user, is_admin: true)
      user_two = insert(:user, is_admin: true)

      conn =
        build_conn()
        |> assign(:user, admin)
        |> put_req_header("accept", "application/json")
        |> delete("/api/pleroma/admin/users/permission_group/admin", %{
          nicknames: [user_one.nickname, user_two.nickname]
        })

      assert json_response(conn, 200) == %{
               "is_admin" => false
             }

      log_entry = Repo.one(ModerationLog)

      assert ModerationLog.get_log_entry_message(log_entry) ==
               "@#{admin.nickname} revoked admin role from @#{user_one.nickname}, @#{
                 user_two.nickname
               }"
    end
  end

  describe "POST /api/pleroma/admin/email_invite, with valid config" do
    setup do
      [user: insert(:user, is_admin: true)]
    end

    clear_config([:instance, :registrations_open]) do
      Pleroma.Config.put([:instance, :registrations_open], false)
    end

    clear_config([:instance, :invites_enabled]) do
      Pleroma.Config.put([:instance, :invites_enabled], true)
    end

    test "sends invitation and returns 204", %{conn: conn, user: user} do
      recipient_email = "foo@bar.com"
      recipient_name = "J. D."

      conn =
        conn
        |> assign(:user, user)
        |> post(
          "/api/pleroma/admin/users/email_invite?email=#{recipient_email}&name=#{recipient_name}"
        )

      assert json_response(conn, :no_content)

      token_record = List.last(Pleroma.Repo.all(Pleroma.UserInviteToken))
      assert token_record
      refute token_record.used

      notify_email = Pleroma.Config.get([:instance, :notify_email])
      instance_name = Pleroma.Config.get([:instance, :name])

      email =
        Pleroma.Emails.UserEmail.user_invitation_email(
          user,
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

    test "it returns 403 if requested by a non-admin", %{conn: conn} do
      non_admin_user = insert(:user)

      conn =
        conn
        |> assign(:user, non_admin_user)
        |> post("/api/pleroma/admin/users/email_invite?email=foo@bar.com&name=JD")

      assert json_response(conn, :forbidden)
    end
  end

  describe "POST /api/pleroma/admin/users/email_invite, with invalid config" do
    setup do
      [user: insert(:user, is_admin: true)]
    end

    clear_config([:instance, :registrations_open])
    clear_config([:instance, :invites_enabled])

    test "it returns 500 if `invites_enabled` is not enabled", %{conn: conn, user: user} do
      Pleroma.Config.put([:instance, :registrations_open], false)
      Pleroma.Config.put([:instance, :invites_enabled], false)

      conn =
        conn
        |> assign(:user, user)
        |> post("/api/pleroma/admin/users/email_invite?email=foo@bar.com&name=JD")

      assert json_response(conn, :internal_server_error)
    end

    test "it returns 500 if `registrations_open` is enabled", %{conn: conn, user: user} do
      Pleroma.Config.put([:instance, :registrations_open], true)
      Pleroma.Config.put([:instance, :invites_enabled], true)

      conn =
        conn
        |> assign(:user, user)
        |> post("/api/pleroma/admin/users/email_invite?email=foo@bar.com&name=JD")

      assert json_response(conn, :internal_server_error)
    end
  end

  test "/api/pleroma/admin/users/:nickname/password_reset" do
    admin = insert(:user, is_admin: true)
    user = insert(:user)

    conn =
      build_conn()
      |> assign(:user, admin)
      |> put_req_header("accept", "application/json")
      |> get("/api/pleroma/admin/users/#{user.nickname}/password_reset")

    resp = json_response(conn, 200)

    assert Regex.match?(~r/(http:\/\/|https:\/\/)/, resp["link"])
  end

  describe "GET /api/pleroma/admin/users" do
    setup do
      admin = insert(:user, is_admin: true)

      conn =
        build_conn()
        |> assign(:user, admin)

      {:ok, conn: conn, admin: admin}
    end

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
      user = insert(:user, nickname: "bob")

      insert(:user, nickname: "bobb", local: false)

      conn =
        build_conn()
        |> assign(:user, admin)
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

    test "only local users with no query", %{admin: old_admin} do
      admin = insert(:user, is_admin: true, nickname: "john")
      user = insert(:user, nickname: "bob")

      insert(:user, nickname: "bobb", local: false)

      conn =
        build_conn()
        |> assign(:user, admin)
        |> get("/api/pleroma/admin/users?filters=local")

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
      user = insert(:user, nickname: "bob", local: false, deactivated: true)

      insert(:user, nickname: "ken", local: true, deactivated: true)
      insert(:user, nickname: "bobb", local: false, deactivated: false)

      conn =
        build_conn()
        |> assign(:user, admin)
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

    test "it omits relay user", %{admin: admin} do
      assert %User{} = Relay.get_actor()

      conn =
        build_conn()
        |> assign(:user, admin)
        |> get("/api/pleroma/admin/users")

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

  test "PATCH /api/pleroma/admin/users/activate" do
    admin = insert(:user, is_admin: true)
    user_one = insert(:user, deactivated: true)
    user_two = insert(:user, deactivated: true)

    conn =
      build_conn()
      |> assign(:user, admin)
      |> patch(
        "/api/pleroma/admin/users/activate",
        %{nicknames: [user_one.nickname, user_two.nickname]}
      )

    response = json_response(conn, 200)
    assert Enum.map(response["users"], & &1["deactivated"]) == [false, false]

    log_entry = Repo.one(ModerationLog)

    assert ModerationLog.get_log_entry_message(log_entry) ==
             "@#{admin.nickname} activated users: @#{user_one.nickname}, @#{user_two.nickname}"
  end

  test "PATCH /api/pleroma/admin/users/deactivate" do
    admin = insert(:user, is_admin: true)
    user_one = insert(:user, deactivated: false)
    user_two = insert(:user, deactivated: false)

    conn =
      build_conn()
      |> assign(:user, admin)
      |> patch(
        "/api/pleroma/admin/users/deactivate",
        %{nicknames: [user_one.nickname, user_two.nickname]}
      )

    response = json_response(conn, 200)
    assert Enum.map(response["users"], & &1["deactivated"]) == [true, true]

    log_entry = Repo.one(ModerationLog)

    assert ModerationLog.get_log_entry_message(log_entry) ==
             "@#{admin.nickname} deactivated users: @#{user_one.nickname}, @#{user_two.nickname}"
  end

  test "PATCH /api/pleroma/admin/users/:nickname/toggle_activation" do
    admin = insert(:user, is_admin: true)
    user = insert(:user)

    conn =
      build_conn()
      |> assign(:user, admin)
      |> patch("/api/pleroma/admin/users/#{user.nickname}/toggle_activation")

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
    setup do
      admin = insert(:user, is_admin: true)

      conn =
        build_conn()
        |> assign(:user, admin)

      {:ok, conn: conn}
    end

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
    setup do
      admin = insert(:user, is_admin: true)

      conn =
        build_conn()
        |> assign(:user, admin)

      {:ok, conn: conn}
    end

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
    test "with token" do
      admin = insert(:user, is_admin: true)
      {:ok, invite} = UserInviteToken.create_invite()

      conn =
        build_conn()
        |> assign(:user, admin)
        |> post("/api/pleroma/admin/users/revoke_invite", %{"token" => invite.token})

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

    test "with invalid token" do
      admin = insert(:user, is_admin: true)

      conn =
        build_conn()
        |> assign(:user, admin)
        |> post("/api/pleroma/admin/users/revoke_invite", %{"token" => "foo"})

      assert json_response(conn, :not_found) == "Not found"
    end
  end

  describe "GET /api/pleroma/admin/reports/:id" do
    setup %{conn: conn} do
      admin = insert(:user, is_admin: true)

      %{conn: assign(conn, :user, admin)}
    end

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
    setup %{conn: conn} do
      admin = insert(:user, is_admin: true)
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
        conn: assign(conn, :user, admin),
        id: report_id,
        admin: admin,
        second_report_id: second_report_id
      }
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
    setup %{conn: conn} do
      admin = insert(:user, is_admin: true)

      %{conn: assign(conn, :user, admin)}
    end

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

      conn =
        build_conn()
        |> assign(:user, user)
        |> get("/api/pleroma/admin/reports")

      assert json_response(conn, :forbidden) == %{"error" => "User is not admin."}
    end

    test "returns 403 when requested by anonymous" do
      conn =
        build_conn()
        |> get("/api/pleroma/admin/reports")

      assert json_response(conn, :forbidden) == %{"error" => "Invalid credentials."}
    end
  end

  describe "GET /api/pleroma/admin/grouped_reports" do
    setup %{conn: conn} do
      admin = insert(:user, is_admin: true)
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
        conn: assign(conn, :user, admin),
        first_status: Activity.get_by_ap_id_with_object(first_status.data["id"]),
        second_status: Activity.get_by_ap_id_with_object(second_status.data["id"]),
        third_status: Activity.get_by_ap_id_with_object(third_status.data["id"]),
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

      first_group =
        Enum.find(response["reports"], &(&1["status"]["id"] == first_status.data["id"]))

      second_group =
        Enum.find(response["reports"], &(&1["status"]["id"] == second_status.data["id"]))

      third_group =
        Enum.find(response["reports"], &(&1["status"]["id"] == third_status.data["id"]))

      assert length(first_group["reports"]) == 3
      assert length(second_group["reports"]) == 2
      assert length(third_group["reports"]) == 1

      assert first_group["date"] ==
               Enum.max_by(first_status_reports, fn act ->
                 NaiveDateTime.from_iso8601!(act.data["published"])
               end).data["published"]

      assert first_group["status"] == %{
               "id" => first_status.data["id"],
               "content" => first_status.object.data["content"],
               "published" => first_status.object.data["published"]
             }

      assert first_group["account"]["id"] == target_user.id

      assert length(first_group["actors"]) == 1
      assert hd(first_group["actors"])["id"] == reporter.id

      assert Enum.map(first_group["reports"], & &1["id"]) --
               Enum.map(first_status_reports, & &1.id) == []

      assert second_group["date"] ==
               Enum.max_by(second_status_reports, fn act ->
                 NaiveDateTime.from_iso8601!(act.data["published"])
               end).data["published"]

      assert second_group["status"] == %{
               "id" => second_status.data["id"],
               "content" => second_status.object.data["content"],
               "published" => second_status.object.data["published"]
             }

      assert second_group["account"]["id"] == target_user.id

      assert length(second_group["actors"]) == 1
      assert hd(second_group["actors"])["id"] == reporter.id

      assert Enum.map(second_group["reports"], & &1["id"]) --
               Enum.map(second_status_reports, & &1.id) == []

      assert third_group["date"] ==
               Enum.max_by(third_status_reports, fn act ->
                 NaiveDateTime.from_iso8601!(act.data["published"])
               end).data["published"]

      assert third_group["status"] == %{
               "id" => third_status.data["id"],
               "content" => third_status.object.data["content"],
               "published" => third_status.object.data["published"]
             }

      assert third_group["account"]["id"] == target_user.id

      assert length(third_group["actors"]) == 1
      assert hd(third_group["actors"])["id"] == reporter.id

      assert Enum.map(third_group["reports"], & &1["id"]) --
               Enum.map(third_status_reports, & &1.id) == []
    end
  end

  describe "POST /api/pleroma/admin/reports/:id/respond" do
    setup %{conn: conn} do
      admin = insert(:user, is_admin: true)

      %{conn: assign(conn, :user, admin), admin: admin}
    end

    test "returns created dm", %{conn: conn, admin: admin} do
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
        |> post("/api/pleroma/admin/reports/#{report_id}/respond", %{
          "status" => "I will check it out"
        })
        |> json_response(:ok)

      recipients = Enum.map(response["mentions"], & &1["username"])

      assert reporter.nickname in recipients
      assert response["content"] == "I will check it out"
      assert response["visibility"] == "direct"

      log_entry = Repo.one(ModerationLog)

      assert ModerationLog.get_log_entry_message(log_entry) ==
               "@#{admin.nickname} responded with 'I will check it out' to report ##{
                 response["id"]
               }"
    end

    test "returns 400 when status is missing", %{conn: conn} do
      conn = post(conn, "/api/pleroma/admin/reports/test/respond")

      assert json_response(conn, :bad_request) == "Invalid parameters"
    end

    test "returns 404 when report id is invalid", %{conn: conn} do
      conn =
        post(conn, "/api/pleroma/admin/reports/test/respond", %{
          "status" => "foo"
        })

      assert json_response(conn, :not_found) == "Not found"
    end
  end

  describe "PUT /api/pleroma/admin/statuses/:id" do
    setup %{conn: conn} do
      admin = insert(:user, is_admin: true)
      activity = insert(:note_activity)

      %{conn: assign(conn, :user, admin), id: activity.id, admin: admin}
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
      conn =
        conn
        |> put("/api/pleroma/admin/statuses/#{id}", %{"visibility" => "test"})

      assert json_response(conn, :bad_request) == "Unsupported visibility"
    end
  end

  describe "DELETE /api/pleroma/admin/statuses/:id" do
    setup %{conn: conn} do
      admin = insert(:user, is_admin: true)
      activity = insert(:note_activity)

      %{conn: assign(conn, :user, admin), id: activity.id, admin: admin}
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

    test "returns error when status is not exist", %{conn: conn} do
      conn =
        conn
        |> delete("/api/pleroma/admin/statuses/test")

      assert json_response(conn, :bad_request) == "Could not delete"
    end
  end

  describe "GET /api/pleroma/admin/config" do
    setup %{conn: conn} do
      admin = insert(:user, is_admin: true)

      %{conn: assign(conn, :user, admin)}
    end

    test "without any settings in db", %{conn: conn} do
      conn = get(conn, "/api/pleroma/admin/config")

      assert json_response(conn, 200) == %{"configs" => []}
    end

    test "with settings in db", %{conn: conn} do
      config1 = insert(:config)
      config2 = insert(:config)

      conn = get(conn, "/api/pleroma/admin/config")

      %{
        "configs" => [
          %{
            "key" => key1,
            "value" => _
          },
          %{
            "key" => key2,
            "value" => _
          }
        ]
      } = json_response(conn, 200)

      assert key1 == config1.key
      assert key2 == config2.key
    end
  end

  describe "POST /api/pleroma/admin/config" do
    setup %{conn: conn} do
      admin = insert(:user, is_admin: true)

      temp_file = "config/test.exported_from_db.secret.exs"

      on_exit(fn ->
        Application.delete_env(:pleroma, :key1)
        Application.delete_env(:pleroma, :key2)
        Application.delete_env(:pleroma, :key3)
        Application.delete_env(:pleroma, :key4)
        Application.delete_env(:pleroma, :keyaa1)
        Application.delete_env(:pleroma, :keyaa2)
        Application.delete_env(:pleroma, Pleroma.Web.Endpoint.NotReal)
        Application.delete_env(:pleroma, Pleroma.Captcha.NotReal)
        :ok = File.rm(temp_file)
      end)

      %{conn: assign(conn, :user, admin)}
    end

    clear_config([:instance, :dynamic_configuration]) do
      Pleroma.Config.put([:instance, :dynamic_configuration], true)
    end

    @tag capture_log: true
    test "create new config setting in db", %{conn: conn} do
      conn =
        post(conn, "/api/pleroma/admin/config", %{
          configs: [
            %{group: "pleroma", key: "key1", value: "value1"},
            %{
              group: "ueberauth",
              key: "Ueberauth.Strategy.Twitter.OAuth",
              value: [%{"tuple" => [":consumer_secret", "aaaa"]}]
            },
            %{
              group: "pleroma",
              key: "key2",
              value: %{
                ":nested_1" => "nested_value1",
                ":nested_2" => [
                  %{":nested_22" => "nested_value222"},
                  %{":nested_33" => %{":nested_44" => "nested_444"}}
                ]
              }
            },
            %{
              group: "pleroma",
              key: "key3",
              value: [
                %{"nested_3" => ":nested_3", "nested_33" => "nested_33"},
                %{"nested_4" => true}
              ]
            },
            %{
              group: "pleroma",
              key: "key4",
              value: %{":nested_5" => ":upload", "endpoint" => "https://example.com"}
            },
            %{
              group: "idna",
              key: "key5",
              value: %{"tuple" => ["string", "Pleroma.Captcha.NotReal", []]}
            }
          ]
        })

      assert json_response(conn, 200) == %{
               "configs" => [
                 %{
                   "group" => "pleroma",
                   "key" => "key1",
                   "value" => "value1"
                 },
                 %{
                   "group" => "ueberauth",
                   "key" => "Ueberauth.Strategy.Twitter.OAuth",
                   "value" => [%{"tuple" => [":consumer_secret", "aaaa"]}]
                 },
                 %{
                   "group" => "pleroma",
                   "key" => "key2",
                   "value" => %{
                     ":nested_1" => "nested_value1",
                     ":nested_2" => [
                       %{":nested_22" => "nested_value222"},
                       %{":nested_33" => %{":nested_44" => "nested_444"}}
                     ]
                   }
                 },
                 %{
                   "group" => "pleroma",
                   "key" => "key3",
                   "value" => [
                     %{"nested_3" => ":nested_3", "nested_33" => "nested_33"},
                     %{"nested_4" => true}
                   ]
                 },
                 %{
                   "group" => "pleroma",
                   "key" => "key4",
                   "value" => %{"endpoint" => "https://example.com", ":nested_5" => ":upload"}
                 },
                 %{
                   "group" => "idna",
                   "key" => "key5",
                   "value" => %{"tuple" => ["string", "Pleroma.Captcha.NotReal", []]}
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

    test "update config setting & delete", %{conn: conn} do
      config1 = insert(:config, key: "keyaa1")
      config2 = insert(:config, key: "keyaa2")

      insert(:config,
        group: "ueberauth",
        key: "Ueberauth.Strategy.Microsoft.OAuth",
        value: :erlang.term_to_binary([])
      )

      conn =
        post(conn, "/api/pleroma/admin/config", %{
          configs: [
            %{group: config1.group, key: config1.key, value: "another_value"},
            %{group: config2.group, key: config2.key, delete: "true"},
            %{
              group: "ueberauth",
              key: "Ueberauth.Strategy.Microsoft.OAuth",
              delete: "true"
            }
          ]
        })

      assert json_response(conn, 200) == %{
               "configs" => [
                 %{
                   "group" => "pleroma",
                   "key" => config1.key,
                   "value" => "another_value"
                 }
               ]
             }

      assert Application.get_env(:pleroma, :keyaa1) == "another_value"
      refute Application.get_env(:pleroma, :keyaa2)
    end

    test "common config example", %{conn: conn} do
      conn =
        post(conn, "/api/pleroma/admin/config", %{
          configs: [
            %{
              "group" => "pleroma",
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
                %{"tuple" => [":regex4", "~r/https:\/\/example.com/s"]}
              ]
            }
          ]
        })

      assert json_response(conn, 200) == %{
               "configs" => [
                 %{
                   "group" => "pleroma",
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
                     %{"tuple" => [":regex4", "~r/https:\\/\\/example.com/s"]}
                   ]
                 }
               ]
             }
    end

    test "tuples with more than two values", %{conn: conn} do
      conn =
        post(conn, "/api/pleroma/admin/config", %{
          configs: [
            %{
              "group" => "pleroma",
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
                   "group" => "pleroma",
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
             }
    end

    test "settings with nesting map", %{conn: conn} do
      conn =
        post(conn, "/api/pleroma/admin/config", %{
          configs: [
            %{
              "group" => "pleroma",
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
                     "group" => "pleroma",
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
                     ]
                   }
                 ]
               }
    end

    test "value as map", %{conn: conn} do
      conn =
        post(conn, "/api/pleroma/admin/config", %{
          configs: [
            %{
              "group" => "pleroma",
              "key" => ":key1",
              "value" => %{"key" => "some_val"}
            }
          ]
        })

      assert json_response(conn, 200) ==
               %{
                 "configs" => [
                   %{
                     "group" => "pleroma",
                     "key" => ":key1",
                     "value" => %{"key" => "some_val"}
                   }
                 ]
               }
    end

    test "dispatch setting", %{conn: conn} do
      conn =
        post(conn, "/api/pleroma/admin/config", %{
          configs: [
            %{
              "group" => "pleroma",
              "key" => "Pleroma.Web.Endpoint.NotReal",
              "value" => [
                %{
                  "tuple" => [
                    ":http",
                    [
                      %{"tuple" => [":ip", %{"tuple" => [127, 0, 0, 1]}]},
                      %{"tuple" => [":dispatch", ["{:_,
       [
         {\"/api/v1/streaming\", Pleroma.Web.MastodonAPI.WebsocketHandler, []},
         {\"/websocket\", Phoenix.Endpoint.CowboyWebSocket,
          {Phoenix.Transports.WebSocket,
           {Pleroma.Web.Endpoint, Pleroma.Web.UserSocket, [path: \"/websocket\"]}}},
         {:_, Phoenix.Endpoint.Cowboy2Handler, {Pleroma.Web.Endpoint, []}}
       ]}"]]}
                    ]
                  ]
                }
              ]
            }
          ]
        })

      dispatch_string =
        "{:_, [{\"/api/v1/streaming\", Pleroma.Web.MastodonAPI.WebsocketHandler, []}, " <>
          "{\"/websocket\", Phoenix.Endpoint.CowboyWebSocket, {Phoenix.Transports.WebSocket, " <>
          "{Pleroma.Web.Endpoint, Pleroma.Web.UserSocket, [path: \"/websocket\"]}}}, " <>
          "{:_, Phoenix.Endpoint.Cowboy2Handler, {Pleroma.Web.Endpoint, []}}]}"

      assert json_response(conn, 200) == %{
               "configs" => [
                 %{
                   "group" => "pleroma",
                   "key" => "Pleroma.Web.Endpoint.NotReal",
                   "value" => [
                     %{
                       "tuple" => [
                         ":http",
                         [
                           %{"tuple" => [":ip", %{"tuple" => [127, 0, 0, 1]}]},
                           %{
                             "tuple" => [
                               ":dispatch",
                               [
                                 dispatch_string
                               ]
                             ]
                           }
                         ]
                       ]
                     }
                   ]
                 }
               ]
             }
    end

    test "queues key as atom", %{conn: conn} do
      conn =
        post(conn, "/api/pleroma/admin/config", %{
          configs: [
            %{
              "group" => "oban",
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
                   "group" => "oban",
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
             }
    end

    test "delete part of settings by atom subkeys", %{conn: conn} do
      config =
        insert(:config,
          key: "keyaa1",
          value: :erlang.term_to_binary(subkey1: "val1", subkey2: "val2", subkey3: "val3")
        )

      conn =
        post(conn, "/api/pleroma/admin/config", %{
          configs: [
            %{
              group: config.group,
              key: config.key,
              subkeys: [":subkey1", ":subkey3"],
              delete: "true"
            }
          ]
        })

      assert(
        json_response(conn, 200) == %{
          "configs" => [
            %{
              "group" => "pleroma",
              "key" => "keyaa1",
              "value" => [%{"tuple" => [":subkey2", "val2"]}]
            }
          ]
        }
      )
    end
  end

  describe "config mix tasks run" do
    setup %{conn: conn} do
      admin = insert(:user, is_admin: true)

      temp_file = "config/test.exported_from_db.secret.exs"

      Mix.shell(Mix.Shell.Quiet)

      on_exit(fn ->
        Mix.shell(Mix.Shell.IO)
        :ok = File.rm(temp_file)
      end)

      %{conn: assign(conn, :user, admin), admin: admin}
    end

    clear_config([:instance, :dynamic_configuration]) do
      Pleroma.Config.put([:instance, :dynamic_configuration], true)
    end

    clear_config([:feed, :post_title]) do
      Pleroma.Config.put([:feed, :post_title], %{max_length: 100, omission: "…"})
    end

    test "transfer settings to DB and to file", %{conn: conn, admin: admin} do
      assert Pleroma.Repo.all(Pleroma.Web.AdminAPI.Config) == []
      conn = get(conn, "/api/pleroma/admin/config/migrate_to_db")
      assert json_response(conn, 200) == %{}
      assert Pleroma.Repo.all(Pleroma.Web.AdminAPI.Config) > 0

      conn =
        build_conn()
        |> assign(:user, admin)
        |> get("/api/pleroma/admin/config/migrate_from_db")

      assert json_response(conn, 200) == %{}
      assert Pleroma.Repo.all(Pleroma.Web.AdminAPI.Config) == []
    end
  end

  describe "GET /api/pleroma/admin/users/:nickname/statuses" do
    setup do
      admin = insert(:user, is_admin: true)
      user = insert(:user)

      date1 = (DateTime.to_unix(DateTime.utc_now()) + 2000) |> DateTime.from_unix!()
      date2 = (DateTime.to_unix(DateTime.utc_now()) + 1000) |> DateTime.from_unix!()
      date3 = (DateTime.to_unix(DateTime.utc_now()) + 3000) |> DateTime.from_unix!()

      insert(:note_activity, user: user, published: date1)
      insert(:note_activity, user: user, published: date2)
      insert(:note_activity, user: user, published: date3)

      conn =
        build_conn()
        |> assign(:user, admin)

      {:ok, conn: conn, user: user}
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
  end

  describe "GET /api/pleroma/admin/moderation_log" do
    setup %{conn: conn} do
      admin = insert(:user, is_admin: true)
      moderator = insert(:user, is_moderator: true)

      %{conn: assign(conn, :user, admin), admin: admin, moderator: moderator}
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
    setup %{conn: conn} do
      admin = insert(:user, is_admin: true)
      user = insert(:user)

      %{conn: assign(conn, :user, admin), admin: admin, user: user}
    end

    test "sets password_reset_pending to true", %{admin: admin, user: user} do
      assert user.password_reset_pending == false

      conn =
        build_conn()
        |> assign(:user, admin)
        |> patch("/api/pleroma/admin/users/force_password_reset", %{nicknames: [user.nickname]})

      assert json_response(conn, 204) == ""

      ObanHelpers.perform_all()

      assert User.get_by_id(user.id).password_reset_pending == true
    end
  end

  describe "relays" do
    setup %{conn: conn} do
      admin = insert(:user, is_admin: true)

      %{conn: assign(conn, :user, admin), admin: admin}
    end

    test "POST /relay", %{admin: admin} do
      conn =
        build_conn()
        |> assign(:user, admin)
        |> post("/api/pleroma/admin/relay", %{
          relay_url: "http://mastodon.example.org/users/admin"
        })

      assert json_response(conn, 200) == "http://mastodon.example.org/users/admin"

      log_entry = Repo.one(ModerationLog)

      assert ModerationLog.get_log_entry_message(log_entry) ==
               "@#{admin.nickname} followed relay: http://mastodon.example.org/users/admin"
    end

    test "GET /relay", %{admin: admin} do
      relay_user = Pleroma.Web.ActivityPub.Relay.get_actor()

      ["http://mastodon.example.org/users/admin", "https://mstdn.io/users/mayuutann"]
      |> Enum.each(fn ap_id ->
        {:ok, user} = User.get_or_fetch_by_ap_id(ap_id)
        User.follow(relay_user, user)
      end)

      conn =
        build_conn()
        |> assign(:user, admin)
        |> get("/api/pleroma/admin/relay")

      assert json_response(conn, 200)["relays"] -- ["mastodon.example.org", "mstdn.io"] == []
    end

    test "DELETE /relay", %{admin: admin} do
      build_conn()
      |> assign(:user, admin)
      |> post("/api/pleroma/admin/relay", %{
        relay_url: "http://mastodon.example.org/users/admin"
      })

      conn =
        build_conn()
        |> assign(:user, admin)
        |> delete("/api/pleroma/admin/relay", %{
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
    test "GET /instances/:instance/statuses" do
      admin = insert(:user, is_admin: true)
      user = insert(:user, local: false, nickname: "archaeme@archae.me")
      user2 = insert(:user, local: false, nickname: "test@test.com")
      insert_pair(:note_activity, user: user)
      insert(:note_activity, user: user2)

      conn =
        build_conn()
        |> assign(:user, admin)
        |> get("/api/pleroma/admin/instances/archae.me/statuses")

      response = json_response(conn, 200)

      assert length(response) == 2

      conn =
        build_conn()
        |> assign(:user, admin)
        |> get("/api/pleroma/admin/instances/test.com/statuses")

      response = json_response(conn, 200)

      assert length(response) == 1

      conn =
        build_conn()
        |> assign(:user, admin)
        |> get("/api/pleroma/admin/instances/nonexistent.com/statuses")

      response = json_response(conn, 200)

      assert length(response) == 0
    end
  end

  describe "PATCH /confirm_email" do
    setup %{conn: conn} do
      admin = insert(:user, is_admin: true)

      %{conn: assign(conn, :user, admin), admin: admin}
    end

    test "it confirms emails of two users", %{admin: admin} do
      [first_user, second_user] = insert_pair(:user, confirmation_pending: true)

      assert first_user.confirmation_pending == true
      assert second_user.confirmation_pending == true

      build_conn()
      |> assign(:user, admin)
      |> patch("/api/pleroma/admin/users/confirm_email", %{
        nicknames: [
          first_user.nickname,
          second_user.nickname
        ]
      })

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
    setup %{conn: conn} do
      admin = insert(:user, is_admin: true)

      %{conn: assign(conn, :user, admin), admin: admin}
    end

    test "it resend emails for two users", %{admin: admin} do
      [first_user, second_user] = insert_pair(:user, confirmation_pending: true)

      build_conn()
      |> assign(:user, admin)
      |> patch("/api/pleroma/admin/users/resend_confirmation_email", %{
        nicknames: [
          first_user.nickname,
          second_user.nickname
        ]
      })

      log_entry = Repo.one(ModerationLog)

      assert ModerationLog.get_log_entry_message(log_entry) ==
               "@#{admin.nickname} re-sent confirmation email for users: @#{first_user.nickname}, @#{
                 second_user.nickname
               }"
    end
  end
end

# Needed for testing
defmodule Pleroma.Web.Endpoint.NotReal do
end

defmodule Pleroma.Captcha.NotReal do
end
