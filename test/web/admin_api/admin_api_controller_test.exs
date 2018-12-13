defmodule Pleroma.Web.AdminAPI.AdminAPIControllerTest do
  use Pleroma.Web.ConnCase

  alias Pleroma.{Repo, User}
  import Pleroma.Factory

  describe "/api/pleroma/admin/user" do
    test "Delete" do
      admin = insert(:user, info: %{is_admin: true})
      user = insert(:user)

      conn =
        build_conn()
        |> assign(:user, admin)
        |> put_req_header("accept", "application/json")
        |> delete("/api/pleroma/admin/user?nickname=#{user.nickname}")

      assert json_response(conn, 200) == user.nickname
    end

    test "Create" do
      admin = insert(:user, info: %{is_admin: true})

      conn =
        build_conn()
        |> assign(:user, admin)
        |> put_req_header("accept", "application/json")
        |> post("/api/pleroma/admin/user", %{
          "nickname" => "lain",
          "email" => "lain@example.org",
          "password" => "test"
        })

      assert json_response(conn, 200) == "lain"
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
      assert Repo.get(User, user1.id).tags == ["x", "foo", "bar"]
      assert Repo.get(User, user2.id).tags == ["y", "foo", "bar"]
    end

    test "it does not modify tags of not specified users", %{conn: conn, user3: user3} do
      assert json_response(conn, :no_content)
      assert Repo.get(User, user3.id).tags == ["unchanged"]
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
      assert Repo.get(User, user1.id).tags == []
      assert Repo.get(User, user2.id).tags == ["y"]
    end

    test "it does not modify tags of not specified users", %{conn: conn, user3: user3} do
      assert json_response(conn, :no_content)
      assert Repo.get(User, user3.id).tags == ["unchanged"]
    end
  end

  describe "/api/pleroma/admin/permission_group" do
    test "GET is giving user_info" do
      admin = insert(:user, info: %{is_admin: true})

      conn =
        build_conn()
        |> assign(:user, admin)
        |> put_req_header("accept", "application/json")
        |> get("/api/pleroma/admin/permission_group/#{admin.nickname}")

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
        |> post("/api/pleroma/admin/permission_group/#{user.nickname}/admin")

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
        |> delete("/api/pleroma/admin/permission_group/#{user.nickname}/admin")

      assert json_response(conn, 200) == %{
               "is_admin" => false
             }
    end
  end

  describe "POST /api/pleroma/admin/email_invite, with valid parameters" do
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
        |> post("/api/pleroma/admin/email_invite?email=#{recipient_email}&name=#{recipient_name}")

      assert json_response(conn, :no_content)

      Swoosh.TestAssertions.assert_email_sent()
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

  test "/api/pleroma/admin/password_reset" do
    admin = insert(:user, info: %{is_admin: true})
    user = insert(:user)

    conn =
      build_conn()
      |> assign(:user, admin)
      |> put_req_header("accept", "application/json")
      |> get("/api/pleroma/admin/password_reset?nickname=#{user.nickname}")

    assert conn.status == 200
  end
end
