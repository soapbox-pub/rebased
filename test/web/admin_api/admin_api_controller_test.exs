# Pleroma: A lightweight social networking server
# Copyright © 2017-2018 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.AdminAPI.AdminAPIControllerTest do
  use Pleroma.Web.ConnCase

  alias Pleroma.User
  alias Pleroma.UserInviteToken
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
        "tags" => []
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

  test "/api/pleroma/admin/invite_token" do
    admin = insert(:user, info: %{is_admin: true})

    conn =
      build_conn()
      |> assign(:user, admin)
      |> put_req_header("accept", "application/json")
      |> get("/api/pleroma/admin/invite_token")

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

      assert json_response(conn, 200) == %{
               "count" => 2,
               "page_size" => 50,
               "users" => [
                 %{
                   "deactivated" => admin.info.deactivated,
                   "id" => admin.id,
                   "nickname" => admin.nickname,
                   "roles" => %{"admin" => true, "moderator" => false},
                   "local" => true,
                   "tags" => []
                 },
                 %{
                   "deactivated" => user.info.deactivated,
                   "id" => user.id,
                   "nickname" => user.nickname,
                   "roles" => %{"admin" => false, "moderator" => false},
                   "local" => false,
                   "tags" => ["foo", "bar"]
                 }
               ]
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
                   "tags" => []
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
                   "tags" => []
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
                   "tags" => []
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
                   "tags" => []
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
                   "tags" => []
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
                   "tags" => []
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
                   "tags" => []
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
                   "tags" => []
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

      assert json_response(conn, 200) == %{
               "count" => 3,
               "page_size" => 50,
               "users" => [
                 %{
                   "deactivated" => user.info.deactivated,
                   "id" => user.id,
                   "nickname" => user.nickname,
                   "roles" => %{"admin" => false, "moderator" => false},
                   "local" => true,
                   "tags" => []
                 },
                 %{
                   "deactivated" => admin.info.deactivated,
                   "id" => admin.id,
                   "nickname" => admin.nickname,
                   "roles" => %{"admin" => true, "moderator" => false},
                   "local" => true,
                   "tags" => []
                 },
                 %{
                   "deactivated" => false,
                   "id" => old_admin.id,
                   "local" => true,
                   "nickname" => old_admin.nickname,
                   "roles" => %{"admin" => true, "moderator" => false},
                   "tags" => []
                 }
               ]
             }
    end

    test "load only admins", %{conn: conn, admin: admin} do
      second_admin = insert(:user, info: %{is_admin: true})
      insert(:user)
      insert(:user)

      conn = get(conn, "/api/pleroma/admin/users?filters=is_admin")

      assert json_response(conn, 200) == %{
               "count" => 2,
               "page_size" => 50,
               "users" => [
                 %{
                   "deactivated" => false,
                   "id" => admin.id,
                   "nickname" => admin.nickname,
                   "roles" => %{"admin" => true, "moderator" => false},
                   "local" => admin.local,
                   "tags" => []
                 },
                 %{
                   "deactivated" => false,
                   "id" => second_admin.id,
                   "nickname" => second_admin.nickname,
                   "roles" => %{"admin" => true, "moderator" => false},
                   "local" => second_admin.local,
                   "tags" => []
                 }
               ]
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
                   "tags" => []
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

      assert json_response(conn, 200) == %{
               "count" => 2,
               "page_size" => 50,
               "users" => [
                 %{
                   "deactivated" => false,
                   "id" => user1.id,
                   "nickname" => user1.nickname,
                   "roles" => %{"admin" => false, "moderator" => false},
                   "local" => user1.local,
                   "tags" => ["first"]
                 },
                 %{
                   "deactivated" => false,
                   "id" => user2.id,
                   "nickname" => user2.nickname,
                   "roles" => %{"admin" => false, "moderator" => false},
                   "local" => user2.local,
                   "tags" => ["second"]
                 }
               ]
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
                   "tags" => []
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
               "tags" => []
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
  end
end
