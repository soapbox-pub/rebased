# Pleroma: A lightweight social networking server
# Copyright © 2017-2022 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.MastodonAPI.Admin.AccountTestController do
  use Pleroma.Web.ConnCase
  use Oban.Testing, repo: Pleroma.Repo

  import Pleroma.Factory

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

  describe "GET /api/v1/admin/accounts" do
    test "search by display name", %{conn: conn} do
      %{id: id} = insert(:user, name: "Display name")
      insert(:user, name: "Other name")

      assert [%{"id" => ^id}] =
               conn
               |> get("/api/v1/admin/accounts?display_name=Display")
               |> json_response_and_validate_schema(200)
    end
  end

  describe "GET /api/v1/admin/accounts/:id" do
    test "show admin-level information", %{conn: conn} do
      %{id: id} =
        insert(:user,
          email: "email@example.com",
          is_confirmed: false,
          is_moderator: true
        )

      assert %{
               "id" => ^id,
               "email" => "email@example.com",
               "confirmed" => false,
               "role" => "moderator"
             } =
               conn
               |> get("/api/v1/admin/accounts/#{id}")
               |> json_response_and_validate_schema(200)
    end
  end

  describe "DELETE /api/v1/admin/accounts/:id" do
    test "delete account", %{conn: conn} do
      %{id: id} = user = insert(:user)

      conn
      |> delete("/api/v1/admin/accounts/#{id}")
      |> json_response_and_validate_schema(200)

      user = Repo.reload!(user)

      assert %{is_active: false} = user
    end
  end

  describe "POST /api/v1/admin/accounts/:id/action" do
    test "disable account", %{conn: conn} do
      %{id: id} = user = insert(:user)

      conn
      |> put_req_header("content-type", "application/json")
      |> post("/api/v1/admin/accounts/#{id}/action", %{
        "type" => "disable"
      })
      |> json_response_and_validate_schema(204)

      user = Repo.reload!(user)

      assert %{is_active: false} = user
    end
  end

  describe "POST /api/v1/admin/accounts/:id/enable" do
    test "enable account", %{conn: conn} do
      %{id: id} = user = insert(:user)
      User.set_activation(user, false)

      conn
      |> post("/api/v1/admin/accounts/#{id}/enable")
      |> json_response_and_validate_schema(200)

      user = Repo.reload!(user)

      assert %{is_active: true} = user
    end
  end

  describe "POST /api/v1/admin/accounts/:id/approve" do
    test "approve account", %{conn: conn} do
      %{id: id} = user = insert(:user, is_approved: false)

      conn
      |> post("/api/v1/admin/accounts/#{id}/approve")
      |> json_response_and_validate_schema(200)

      user = Repo.reload!(user)

      assert %{is_approved: true} = user
    end
  end

  describe "POST /api/v1/admin/accounts/:id/rejct" do
    test "reject account", %{conn: conn} do
      %{id: id} = user = insert(:user, is_approved: false)

      conn
      |> post("/api/v1/admin/accounts/#{id}/reject")
      |> json_response_and_validate_schema(200)

      user = Repo.reload!(user)

      assert %{is_active: false} = user
    end

    test "do not allow rejecting already accepted accounts", %{conn: conn} do
      %{id: id} = user = insert(:user, is_approved: true)

      assert %{"error" => "User is approved"} ==
               conn
               |> post("/api/v1/admin/accounts/#{id}/reject")
               |> json_response_and_validate_schema(400)

      user = Repo.reload!(user)

      assert %{is_approved: true} = user
    end
  end
end
