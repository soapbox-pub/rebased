# Pleroma: A lightweight social networking server
# Copyright © 2017-2018 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.AdminAPI.AdminAPIControllerTest do
  use Pleroma.Web.ConnCase

  alias Pleroma.Activity
  alias Pleroma.HTML
  alias Pleroma.User
  alias Pleroma.UserInviteToken
  alias Pleroma.Web.CommonAPI
  alias Pleroma.Web.MediaProxy
  import Pleroma.Factory

  describe "/api/pleroma/admin/users" do
    test "Delete" do
      admin = insert(:user, info: %{is_admin: true})
      user = insert(:user)

      conn =
        build_conn()
        |> assign(:user, admin)
        |> put_req_header("accept", "application/json")
        |> delete("/api/pleroma/admin/users?nickname=#{user.nickname}")

      assert json_response(conn, 200) == user.nickname
    end

    test "Create" do
      admin = insert(:user, info: %{is_admin: true})

      conn =
        build_conn()
        |> assign(:user, admin)
        |> put_req_header("accept", "application/json")
        |> post("/api/pleroma/admin/users", %{
          "nickname" => "lain",
          "email" => "lain@example.org",
          "password" => "test"
        })

      assert json_response(conn, 200) == "lain"
    end
  end

  describe "/api/pleroma/admin/users/:nickname" do
    test "Show", %{conn: conn} do
      admin = insert(:user, info: %{is_admin: true})
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
        "display_name" => HTML.strip_tags(user.name || user.nickname)
      }

      assert expected == json_response(conn, 200)
    end

    test "when the user doesn't exist", %{conn: conn} do
      admin = insert(:user, info: %{is_admin: true})
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
      admin = insert(:user, info: %{is_admin: true})
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
    end
  end

  describe "/api/pleroma/admin/users/unfollow" do
    test "allows to force-unfollow another user" do
      admin = insert(:user, info: %{is_admin: true})
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
    end
  end

  describe "PUT /api/pleroma/admin/users/tag" do
    setup do
      admin = insert(:user, info: %{is_admin: true})
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

      %{conn: conn, user1: user1, user2: user2, user3: user3}
    end

    test "it appends specified tags to users with specified nicknames", %{
      conn: conn,
      user1: user1,
      user2: user2
    } do
      assert json_response(conn, :no_content)
      assert User.get_cached_by_id(user1.id).tags == ["x", "foo", "bar"]
      assert User.get_cached_by_id(user2.id).tags == ["y", "foo", "bar"]
    end

    test "it does not modify tags of not specified users", %{conn: conn, user3: user3} do
      assert json_response(conn, :no_content)
      assert User.get_cached_by_id(user3.id).tags == ["unchanged"]
    end
  end

  describe "DELETE /api/pleroma/admin/users/tag" do
    setup do
      admin = insert(:user, info: %{is_admin: true})
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

      %{conn: conn, user1: user1, user2: user2, user3: user3}
    end

    test "it removes specified tags from users with specified nicknames", %{
      conn: conn,
      user1: user1,
      user2: user2
    } do
      assert json_response(conn, :no_content)
      assert User.get_cached_by_id(user1.id).tags == []
      assert User.get_cached_by_id(user2.id).tags == ["y"]
    end

    test "it does not modify tags of not specified users", %{conn: conn, user3: user3} do
      assert json_response(conn, :no_content)
      assert User.get_cached_by_id(user3.id).tags == ["unchanged"]
    end
  end

  describe "/api/pleroma/admin/users/:nickname/permission_group" do
    test "GET is giving user_info" do
      admin = insert(:user, info: %{is_admin: true})

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
      admin = insert(:user, info: %{is_admin: true})
      user = insert(:user)

      conn =
        build_conn()
        |> assign(:user, admin)
        |> put_req_header("accept", "application/json")
        |> post("/api/pleroma/admin/users/#{user.nickname}/permission_group/admin")

      assert json_response(conn, 200) == %{
               "is_admin" => true
             }
    end

    test "/:right DELETE, can remove from a permission group" do
      admin = insert(:user, info: %{is_admin: true})
      user = insert(:user, info: %{is_admin: true})

      conn =
        build_conn()
        |> assign(:user, admin)
        |> put_req_header("accept", "application/json")
        |> delete("/api/pleroma/admin/users/#{user.nickname}/permission_group/admin")

      assert json_response(conn, 200) == %{
               "is_admin" => false
             }
    end
  end

  describe "PUT /api/pleroma/admin/users/:nickname/activation_status" do
    setup %{conn: conn} do
      admin = insert(:user, info: %{is_admin: true})

      conn =
        conn
        |> assign(:user, admin)
        |> put_req_header("accept", "application/json")

      %{conn: conn}
    end

    test "deactivates the user", %{conn: conn} do
      user = insert(:user)

      conn =
        conn
        |> put("/api/pleroma/admin/users/#{user.nickname}/activation_status", %{status: false})

      user = User.get_cached_by_id(user.id)
      assert user.info.deactivated == true
      assert json_response(conn, :no_content)
    end

    test "activates the user", %{conn: conn} do
      user = insert(:user, info: %{deactivated: true})

      conn =
        conn
        |> put("/api/pleroma/admin/users/#{user.nickname}/activation_status", %{status: true})

      user = User.get_cached_by_id(user.id)
      assert user.info.deactivated == false
      assert json_response(conn, :no_content)
    end

    test "returns 403 when requested by a non-admin", %{conn: conn} do
      user = insert(:user)

      conn =
        conn
        |> assign(:user, user)
        |> put("/api/pleroma/admin/users/#{user.nickname}/activation_status", %{status: false})

      assert json_response(conn, :forbidden)
    end
  end

  describe "POST /api/pleroma/admin/email_invite, with valid config" do
    setup do
      registrations_open = Pleroma.Config.get([:instance, :registrations_open])
      invites_enabled = Pleroma.Config.get([:instance, :invites_enabled])
      Pleroma.Config.put([:instance, :registrations_open], false)
      Pleroma.Config.put([:instance, :invites_enabled], true)

      on_exit(fn ->
        Pleroma.Config.put([:instance, :registrations_open], registrations_open)
        Pleroma.Config.put([:instance, :invites_enabled], invites_enabled)
        :ok
      end)

      [user: insert(:user, info: %{is_admin: true})]
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
      [user: insert(:user, info: %{is_admin: true})]
    end

    test "it returns 500 if `invites_enabled` is not enabled", %{conn: conn, user: user} do
      registrations_open = Pleroma.Config.get([:instance, :registrations_open])
      invites_enabled = Pleroma.Config.get([:instance, :invites_enabled])
      Pleroma.Config.put([:instance, :registrations_open], false)
      Pleroma.Config.put([:instance, :invites_enabled], false)

      on_exit(fn ->
        Pleroma.Config.put([:instance, :registrations_open], registrations_open)
        Pleroma.Config.put([:instance, :invites_enabled], invites_enabled)
        :ok
      end)

      conn =
        conn
        |> assign(:user, user)
        |> post("/api/pleroma/admin/users/email_invite?email=foo@bar.com&name=JD")

      assert json_response(conn, :internal_server_error)
    end

    test "it returns 500 if `registrations_open` is enabled", %{conn: conn, user: user} do
      registrations_open = Pleroma.Config.get([:instance, :registrations_open])
      invites_enabled = Pleroma.Config.get([:instance, :invites_enabled])
      Pleroma.Config.put([:instance, :registrations_open], true)
      Pleroma.Config.put([:instance, :invites_enabled], true)

      on_exit(fn ->
        Pleroma.Config.put([:instance, :registrations_open], registrations_open)
        Pleroma.Config.put([:instance, :invites_enabled], invites_enabled)
        :ok
      end)

      conn =
        conn
        |> assign(:user, user)
        |> post("/api/pleroma/admin/users/email_invite?email=foo@bar.com&name=JD")

      assert json_response(conn, :internal_server_error)
    end
  end

  test "/api/pleroma/admin/users/invite_token" do
    admin = insert(:user, info: %{is_admin: true})

    conn =
      build_conn()
      |> assign(:user, admin)
      |> put_req_header("accept", "application/json")
      |> get("/api/pleroma/admin/users/invite_token")

    assert conn.status == 200
  end

  test "/api/pleroma/admin/users/:nickname/password_reset" do
    admin = insert(:user, info: %{is_admin: true})
    user = insert(:user)

    conn =
      build_conn()
      |> assign(:user, admin)
      |> put_req_header("accept", "application/json")
      |> get("/api/pleroma/admin/users/#{user.nickname}/password_reset")

    assert conn.status == 200
  end

  describe "GET /api/pleroma/admin/users" do
    setup do
      admin = insert(:user, info: %{is_admin: true})

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
            "deactivated" => admin.info.deactivated,
            "id" => admin.id,
            "nickname" => admin.nickname,
            "roles" => %{"admin" => true, "moderator" => false},
            "local" => true,
            "tags" => [],
            "avatar" => User.avatar_url(admin) |> MediaProxy.url(),
            "display_name" => HTML.strip_tags(admin.name || admin.nickname)
          },
          %{
            "deactivated" => user.info.deactivated,
            "id" => user.id,
            "nickname" => user.nickname,
            "roles" => %{"admin" => false, "moderator" => false},
            "local" => false,
            "tags" => ["foo", "bar"],
            "avatar" => User.avatar_url(user) |> MediaProxy.url(),
            "display_name" => HTML.strip_tags(user.name || user.nickname)
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
                   "deactivated" => user.info.deactivated,
                   "id" => user.id,
                   "nickname" => user.nickname,
                   "roles" => %{"admin" => false, "moderator" => false},
                   "local" => true,
                   "tags" => [],
                   "avatar" => User.avatar_url(user) |> MediaProxy.url(),
                   "display_name" => HTML.strip_tags(user.name || user.nickname)
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
                   "deactivated" => user.info.deactivated,
                   "id" => user.id,
                   "nickname" => user.nickname,
                   "roles" => %{"admin" => false, "moderator" => false},
                   "local" => true,
                   "tags" => [],
                   "avatar" => User.avatar_url(user) |> MediaProxy.url(),
                   "display_name" => HTML.strip_tags(user.name || user.nickname)
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
                   "deactivated" => user.info.deactivated,
                   "id" => user.id,
                   "nickname" => user.nickname,
                   "roles" => %{"admin" => false, "moderator" => false},
                   "local" => true,
                   "tags" => [],
                   "avatar" => User.avatar_url(user) |> MediaProxy.url(),
                   "display_name" => HTML.strip_tags(user.name || user.nickname)
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
                   "deactivated" => user.info.deactivated,
                   "id" => user.id,
                   "nickname" => user.nickname,
                   "roles" => %{"admin" => false, "moderator" => false},
                   "local" => true,
                   "tags" => [],
                   "avatar" => User.avatar_url(user) |> MediaProxy.url(),
                   "display_name" => HTML.strip_tags(user.name || user.nickname)
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
                   "deactivated" => user.info.deactivated,
                   "id" => user.id,
                   "nickname" => user.nickname,
                   "roles" => %{"admin" => false, "moderator" => false},
                   "local" => true,
                   "tags" => [],
                   "avatar" => User.avatar_url(user) |> MediaProxy.url(),
                   "display_name" => HTML.strip_tags(user.name || user.nickname)
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
                   "deactivated" => user.info.deactivated,
                   "id" => user.id,
                   "nickname" => user.nickname,
                   "roles" => %{"admin" => false, "moderator" => false},
                   "local" => true,
                   "tags" => [],
                   "avatar" => User.avatar_url(user) |> MediaProxy.url(),
                   "display_name" => HTML.strip_tags(user.name || user.nickname)
                 }
               ]
             }

      conn2 = get(conn, "/api/pleroma/admin/users?query=a&page_size=1&page=2")

      assert json_response(conn2, 200) == %{
               "count" => 2,
               "page_size" => 1,
               "users" => [
                 %{
                   "deactivated" => user2.info.deactivated,
                   "id" => user2.id,
                   "nickname" => user2.nickname,
                   "roles" => %{"admin" => false, "moderator" => false},
                   "local" => true,
                   "tags" => [],
                   "avatar" => User.avatar_url(user2) |> MediaProxy.url(),
                   "display_name" => HTML.strip_tags(user2.name || user2.nickname)
                 }
               ]
             }
    end

    test "only local users" do
      admin = insert(:user, info: %{is_admin: true}, nickname: "john")
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
                   "deactivated" => user.info.deactivated,
                   "id" => user.id,
                   "nickname" => user.nickname,
                   "roles" => %{"admin" => false, "moderator" => false},
                   "local" => true,
                   "tags" => [],
                   "avatar" => User.avatar_url(user) |> MediaProxy.url(),
                   "display_name" => HTML.strip_tags(user.name || user.nickname)
                 }
               ]
             }
    end

    test "only local users with no query", %{admin: old_admin} do
      admin = insert(:user, info: %{is_admin: true}, nickname: "john")
      user = insert(:user, nickname: "bob")

      insert(:user, nickname: "bobb", local: false)

      conn =
        build_conn()
        |> assign(:user, admin)
        |> get("/api/pleroma/admin/users?filters=local")

      users =
        [
          %{
            "deactivated" => user.info.deactivated,
            "id" => user.id,
            "nickname" => user.nickname,
            "roles" => %{"admin" => false, "moderator" => false},
            "local" => true,
            "tags" => [],
            "avatar" => User.avatar_url(user) |> MediaProxy.url(),
            "display_name" => HTML.strip_tags(user.name || user.nickname)
          },
          %{
            "deactivated" => admin.info.deactivated,
            "id" => admin.id,
            "nickname" => admin.nickname,
            "roles" => %{"admin" => true, "moderator" => false},
            "local" => true,
            "tags" => [],
            "avatar" => User.avatar_url(admin) |> MediaProxy.url(),
            "display_name" => HTML.strip_tags(admin.name || admin.nickname)
          },
          %{
            "deactivated" => false,
            "id" => old_admin.id,
            "local" => true,
            "nickname" => old_admin.nickname,
            "roles" => %{"admin" => true, "moderator" => false},
            "tags" => [],
            "avatar" => User.avatar_url(old_admin) |> MediaProxy.url(),
            "display_name" => HTML.strip_tags(old_admin.name || old_admin.nickname)
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
      second_admin = insert(:user, info: %{is_admin: true})
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
            "display_name" => HTML.strip_tags(admin.name || admin.nickname)
          },
          %{
            "deactivated" => false,
            "id" => second_admin.id,
            "nickname" => second_admin.nickname,
            "roles" => %{"admin" => true, "moderator" => false},
            "local" => second_admin.local,
            "tags" => [],
            "avatar" => User.avatar_url(second_admin) |> MediaProxy.url(),
            "display_name" => HTML.strip_tags(second_admin.name || second_admin.nickname)
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
      moderator = insert(:user, info: %{is_moderator: true})
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
                   "display_name" => HTML.strip_tags(moderator.name || moderator.nickname)
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
            "display_name" => HTML.strip_tags(user1.name || user1.nickname)
          },
          %{
            "deactivated" => false,
            "id" => user2.id,
            "nickname" => user2.nickname,
            "roles" => %{"admin" => false, "moderator" => false},
            "local" => user2.local,
            "tags" => ["second"],
            "avatar" => User.avatar_url(user2) |> MediaProxy.url(),
            "display_name" => HTML.strip_tags(user2.name || user2.nickname)
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
      admin = insert(:user, nickname: "john", info: %{is_admin: true})
      user = insert(:user, nickname: "bob", local: false, info: %{deactivated: true})

      insert(:user, nickname: "ken", local: true, info: %{deactivated: true})
      insert(:user, nickname: "bobb", local: false, info: %{deactivated: false})

      conn =
        build_conn()
        |> assign(:user, admin)
        |> get("/api/pleroma/admin/users?filters=deactivated,external")

      assert json_response(conn, 200) == %{
               "count" => 1,
               "page_size" => 50,
               "users" => [
                 %{
                   "deactivated" => user.info.deactivated,
                   "id" => user.id,
                   "nickname" => user.nickname,
                   "roles" => %{"admin" => false, "moderator" => false},
                   "local" => user.local,
                   "tags" => [],
                   "avatar" => User.avatar_url(user) |> MediaProxy.url(),
                   "display_name" => HTML.strip_tags(user.name || user.nickname)
                 }
               ]
             }
    end
  end

  test "PATCH /api/pleroma/admin/users/:nickname/toggle_activation" do
    admin = insert(:user, info: %{is_admin: true})
    user = insert(:user)

    conn =
      build_conn()
      |> assign(:user, admin)
      |> patch("/api/pleroma/admin/users/#{user.nickname}/toggle_activation")

    assert json_response(conn, 200) ==
             %{
               "deactivated" => !user.info.deactivated,
               "id" => user.id,
               "nickname" => user.nickname,
               "roles" => %{"admin" => false, "moderator" => false},
               "local" => true,
               "tags" => [],
               "avatar" => User.avatar_url(user) |> MediaProxy.url(),
               "display_name" => HTML.strip_tags(user.name || user.nickname)
             }
  end

  describe "GET /api/pleroma/admin/users/invite_token" do
    setup do
      admin = insert(:user, info: %{is_admin: true})

      conn =
        build_conn()
        |> assign(:user, admin)

      {:ok, conn: conn}
    end

    test "without options", %{conn: conn} do
      conn = get(conn, "/api/pleroma/admin/users/invite_token")

      token = json_response(conn, 200)
      invite = UserInviteToken.find_by_token!(token)
      refute invite.used
      refute invite.expires_at
      refute invite.max_use
      assert invite.invite_type == "one_time"
    end

    test "with expires_at", %{conn: conn} do
      conn =
        get(conn, "/api/pleroma/admin/users/invite_token", %{
          "invite" => %{"expires_at" => Date.to_string(Date.utc_today())}
        })

      token = json_response(conn, 200)
      invite = UserInviteToken.find_by_token!(token)

      refute invite.used
      assert invite.expires_at == Date.utc_today()
      refute invite.max_use
      assert invite.invite_type == "date_limited"
    end

    test "with max_use", %{conn: conn} do
      conn =
        get(conn, "/api/pleroma/admin/users/invite_token", %{
          "invite" => %{"max_use" => 150}
        })

      token = json_response(conn, 200)
      invite = UserInviteToken.find_by_token!(token)
      refute invite.used
      refute invite.expires_at
      assert invite.max_use == 150
      assert invite.invite_type == "reusable"
    end

    test "with max use and expires_at", %{conn: conn} do
      conn =
        get(conn, "/api/pleroma/admin/users/invite_token", %{
          "invite" => %{"max_use" => 150, "expires_at" => Date.to_string(Date.utc_today())}
        })

      token = json_response(conn, 200)
      invite = UserInviteToken.find_by_token!(token)
      refute invite.used
      assert invite.expires_at == Date.utc_today()
      assert invite.max_use == 150
      assert invite.invite_type == "reusable_date_limited"
    end
  end

  describe "GET /api/pleroma/admin/users/invites" do
    setup do
      admin = insert(:user, info: %{is_admin: true})

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
      admin = insert(:user, info: %{is_admin: true})
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
      admin = insert(:user, info: %{is_admin: true})

      conn =
        build_conn()
        |> assign(:user, admin)
        |> post("/api/pleroma/admin/users/revoke_invite", %{"token" => "foo"})

      assert json_response(conn, :not_found) == "Not found"
    end
  end

  describe "GET /api/pleroma/admin/reports/:id" do
    setup %{conn: conn} do
      admin = insert(:user, info: %{is_admin: true})

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

  describe "PUT /api/pleroma/admin/reports/:id" do
    setup %{conn: conn} do
      admin = insert(:user, info: %{is_admin: true})
      [reporter, target_user] = insert_pair(:user)
      activity = insert(:note_activity, user: target_user)

      {:ok, %{id: report_id}} =
        CommonAPI.report(reporter, %{
          "account_id" => target_user.id,
          "comment" => "I feel offended",
          "status_ids" => [activity.id]
        })

      %{conn: assign(conn, :user, admin), id: report_id}
    end

    test "mark report as resolved", %{conn: conn, id: id} do
      response =
        conn
        |> put("/api/pleroma/admin/reports/#{id}", %{"state" => "resolved"})
        |> json_response(:ok)

      assert response["state"] == "resolved"
    end

    test "closes report", %{conn: conn, id: id} do
      response =
        conn
        |> put("/api/pleroma/admin/reports/#{id}", %{"state" => "closed"})
        |> json_response(:ok)

      assert response["state"] == "closed"
    end

    test "returns 400 when state is unknown", %{conn: conn, id: id} do
      conn =
        conn
        |> put("/api/pleroma/admin/reports/#{id}", %{"state" => "test"})

      assert json_response(conn, :bad_request) == "Unsupported state"
    end

    test "returns 404 when report is not exist", %{conn: conn} do
      conn =
        conn
        |> put("/api/pleroma/admin/reports/test", %{"state" => "closed"})

      assert json_response(conn, :not_found) == "Not found"
    end
  end

  describe "GET /api/pleroma/admin/reports" do
    setup %{conn: conn} do
      admin = insert(:user, info: %{is_admin: true})

      %{conn: assign(conn, :user, admin)}
    end

    test "returns empty response when no reports created", %{conn: conn} do
      response =
        conn
        |> get("/api/pleroma/admin/reports")
        |> json_response(:ok)

      assert Enum.empty?(response["reports"])
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

      response =
        conn
        |> get("/api/pleroma/admin/reports", %{
          "state" => "closed"
        })
        |> json_response(:ok)

      [closed_report] = response["reports"]

      assert length(response["reports"]) == 1
      assert closed_report["id"] == second_report_id

      response =
        conn
        |> get("/api/pleroma/admin/reports", %{
          "state" => "resolved"
        })
        |> json_response(:ok)

      assert Enum.empty?(response["reports"])
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

  describe "POST /api/pleroma/admin/reports/:id/respond" do
    setup %{conn: conn} do
      admin = insert(:user, info: %{is_admin: true})

      %{conn: assign(conn, :user, admin)}
    end

    test "returns created dm", %{conn: conn} do
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
      admin = insert(:user, info: %{is_admin: true})
      activity = insert(:note_activity)

      %{conn: assign(conn, :user, admin), id: activity.id}
    end

    test "toggle sensitive flag", %{conn: conn, id: id} do
      response =
        conn
        |> put("/api/pleroma/admin/statuses/#{id}", %{"sensitive" => "true"})
        |> json_response(:ok)

      assert response["sensitive"]

      response =
        conn
        |> put("/api/pleroma/admin/statuses/#{id}", %{"sensitive" => "false"})
        |> json_response(:ok)

      refute response["sensitive"]
    end

    test "change visibility flag", %{conn: conn, id: id} do
      response =
        conn
        |> put("/api/pleroma/admin/statuses/#{id}", %{"visibility" => "public"})
        |> json_response(:ok)

      assert response["visibility"] == "public"

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
      admin = insert(:user, info: %{is_admin: true})
      activity = insert(:note_activity)

      %{conn: assign(conn, :user, admin), id: activity.id}
    end

    test "deletes status", %{conn: conn, id: id} do
      conn
      |> delete("/api/pleroma/admin/statuses/#{id}")
      |> json_response(:ok)

      refute Activity.get_by_id(id)
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
      admin = insert(:user, info: %{is_admin: true})

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
      admin = insert(:user, info: %{is_admin: true})

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

      dynamic = Pleroma.Config.get([:instance, :dynamic_configuration])

      Pleroma.Config.put([:instance, :dynamic_configuration], true)

      on_exit(fn ->
        Pleroma.Config.put([:instance, :dynamic_configuration], dynamic)
      end)

      %{conn: assign(conn, :user, admin)}
    end

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
                %{"tuple" => [":partial_chain", "&:hackney_connect.partial_chain/1"]}
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
                     %{"tuple" => [":partial_chain", "&:hackney_connect.partial_chain/1"]}
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
              "group" => "pleroma_job_queue",
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
                   "group" => "pleroma_job_queue",
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
  end
end

# Needed for testing
defmodule Pleroma.Web.Endpoint.NotReal do
end

defmodule Pleroma.Captcha.NotReal do
end
