defmodule Pleroma.Web.AdminAPI.AdminAPIControllerTest do
  use Pleroma.Web.ConnCase

  alias Pleroma.{Repo, User}

  import Pleroma.Factory
  import ExUnit.CaptureLog

  describe "/api/pleroma/admin/user" do
    test "Delete" do
      admin = insert(:user, info: %{"is_admin" => true})
      user = insert(:user)

      conn =
        build_conn()
        |> assign(:user, admin)
        |> put_req_header("accept", "application/json")
        |> delete("/api/pleroma/admin/user?nickname=#{user.nickname}")

      assert json_response(conn, 200) == user.nickname
    end

    test "Create" do
      admin = insert(:user, info: %{"is_admin" => true})

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

  describe "/api/pleroma/admin/permission_group" do
    test "GET is giving user_info" do
      admin = insert(:user, info: %{"is_admin" => true})

      conn =
        build_conn()
        |> assign(:user, admin)
        |> put_req_header("accept", "application/json")
        |> get("/api/pleroma/admin/permission_group/#{admin.nickname}")

      assert json_response(conn, 200) == admin.info
    end

    test "/:right POST, can add to a permission group" do
      admin = insert(:user, info: %{"is_admin" => true})
      user = insert(:user)

      user_info =
        user.info
        |> Map.put("is_admin", true)

      conn =
        build_conn()
        |> assign(:user, admin)
        |> put_req_header("accept", "application/json")
        |> post("/api/pleroma/admin/permission_group/#{user.nickname}/admin")

      assert json_response(conn, 200) == user_info
    end

    test "/:right DELETE, can remove from a permission group" do
      admin = insert(:user, info: %{"is_admin" => true})
      user = insert(:user, info: %{"is_admin" => true})

      user_info =
        user.info
        |> Map.put("is_admin", false)

      conn =
        build_conn()
        |> assign(:user, admin)
        |> put_req_header("accept", "application/json")
        |> delete("/api/pleroma/admin/permission_group/#{user.nickname}/admin")

      assert json_response(conn, 200) == user_info
    end
  end

  test "/api/pleroma/admin/invite_token" do
    admin = insert(:user, info: %{"is_admin" => true})

    conn =
      build_conn()
      |> assign(:user, admin)
      |> put_req_header("accept", "application/json")
      |> get("/api/pleroma/admin/invite_token")

    assert conn.status == 200
  end

  test "/api/pleroma/admin/password_reset" do
    admin = insert(:user, info: %{"is_admin" => true})
    user = insert(:user, info: %{"is_admin" => true})

    conn =
      build_conn()
      |> assign(:user, admin)
      |> put_req_header("accept", "application/json")
      |> get("/api/pleroma/admin/password_reset?nickname=#{user.nickname}")

    assert conn.status == 200
  end
end
