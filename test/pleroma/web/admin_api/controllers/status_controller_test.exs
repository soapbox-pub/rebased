# Pleroma: A lightweight social networking server
# Copyright © 2017-2022 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.AdminAPI.StatusControllerTest do
  use Pleroma.Web.ConnCase, async: true

  import Pleroma.Factory

  alias Pleroma.Activity
  alias Pleroma.ModerationLog
  alias Pleroma.Repo
  alias Pleroma.User
  alias Pleroma.Web.CommonAPI

  setup do
    admin = insert(:user, is_admin: true)
    token = insert(:oauth_admin_token, user: admin)

    conn =
      build_conn()
      |> assign(:user, admin)
      |> assign(:token, token)

    {:ok, %{admin: admin, token: token, conn: conn}}
  end

  describe "GET /api/pleroma/admin/statuses/:id" do
    test "not found", %{conn: conn} do
      assert conn
             |> get("/api/pleroma/admin/statuses/not_found")
             |> json_response_and_validate_schema(:not_found)
    end

    test "shows activity", %{conn: conn} do
      activity = insert(:note_activity)

      response =
        conn
        |> get("/api/pleroma/admin/statuses/#{activity.id}")
        |> json_response_and_validate_schema(200)

      assert response["id"] == activity.id

      account = response["account"]
      actor = User.get_by_ap_id(activity.actor)

      assert account["id"] == actor.id
      assert account["nickname"] == actor.nickname
      assert account["is_active"] == actor.is_active
      assert account["is_confirmed"] == actor.is_confirmed
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
        |> put_req_header("content-type", "application/json")
        |> put("/api/pleroma/admin/statuses/#{id}", %{"sensitive" => "true"})
        |> json_response_and_validate_schema(:ok)

      assert response["sensitive"]

      log_entry = Repo.one(ModerationLog)

      assert ModerationLog.get_log_entry_message(log_entry) ==
               "@#{admin.nickname} updated status ##{id}, set sensitive: 'true'"

      response =
        conn
        |> put_req_header("content-type", "application/json")
        |> put("/api/pleroma/admin/statuses/#{id}", %{"sensitive" => "false"})
        |> json_response_and_validate_schema(:ok)

      refute response["sensitive"]
    end

    test "change visibility flag", %{conn: conn, id: id, admin: admin} do
      response =
        conn
        |> put_req_header("content-type", "application/json")
        |> put("/api/pleroma/admin/statuses/#{id}", %{visibility: "public"})
        |> json_response_and_validate_schema(:ok)

      assert response["visibility"] == "public"

      log_entry = Repo.one(ModerationLog)

      assert ModerationLog.get_log_entry_message(log_entry) ==
               "@#{admin.nickname} updated status ##{id}, set visibility: 'public'"

      response =
        conn
        |> put_req_header("content-type", "application/json")
        |> put("/api/pleroma/admin/statuses/#{id}", %{visibility: "private"})
        |> json_response_and_validate_schema(:ok)

      assert response["visibility"] == "private"

      response =
        conn
        |> put_req_header("content-type", "application/json")
        |> put("/api/pleroma/admin/statuses/#{id}", %{visibility: "unlisted"})
        |> json_response_and_validate_schema(:ok)

      assert response["visibility"] == "unlisted"
    end

    test "returns 400 when visibility is unknown", %{conn: conn, id: id} do
      conn =
        conn
        |> put_req_header("content-type", "application/json")
        |> put("/api/pleroma/admin/statuses/#{id}", %{visibility: "test"})

      assert %{"error" => "test - Invalid value for enum."} =
               json_response_and_validate_schema(conn, :bad_request)
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
      |> json_response_and_validate_schema(:ok)

      refute Activity.get_by_id(id)

      log_entry = Repo.one(ModerationLog)

      assert ModerationLog.get_log_entry_message(log_entry) ==
               "@#{admin.nickname} deleted status ##{id}"
    end

    test "returns 404 when the status does not exist", %{conn: conn} do
      conn = delete(conn, "/api/pleroma/admin/statuses/test")

      assert json_response_and_validate_schema(conn, :not_found) == %{"error" => "Not found"}
    end
  end

  describe "GET /api/pleroma/admin/statuses" do
    setup do
      clear_config([:instance, :admin_privileges], [:statuses_read])
    end

    test "returns all public and unlisted statuses", %{conn: conn, admin: admin} do
      blocked = insert(:user)
      user = insert(:user)
      User.block(admin, blocked)

      {:ok, _} = CommonAPI.post(user, %{status: "@#{admin.nickname}", visibility: "direct"})

      {:ok, _} = CommonAPI.post(user, %{status: ".", visibility: "unlisted"})
      {:ok, _} = CommonAPI.post(user, %{status: ".", visibility: "private"})
      {:ok, _} = CommonAPI.post(user, %{status: ".", visibility: "public"})
      {:ok, _} = CommonAPI.post(blocked, %{status: ".", visibility: "public"})

      response =
        conn
        |> get("/api/pleroma/admin/statuses")
        |> json_response_and_validate_schema(200)

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
        |> json_response_and_validate_schema(200)

      assert length(response) == 1
    end

    test "returns private and direct statuses with godmode on", %{conn: conn, admin: admin} do
      user = insert(:user)

      {:ok, _} = CommonAPI.post(user, %{status: "@#{admin.nickname}", visibility: "direct"})

      {:ok, _} = CommonAPI.post(user, %{status: ".", visibility: "private"})
      {:ok, _} = CommonAPI.post(user, %{status: ".", visibility: "public"})
      conn = get(conn, "/api/pleroma/admin/statuses?godmode=true")
      assert json_response_and_validate_schema(conn, 200) |> length() == 3
    end

    test "it requires privileged role :statuses_read", %{conn: conn} do
      clear_config([:instance, :admin_privileges], [])

      conn = get(conn, "/api/pleroma/admin/statuses")

      assert json_response(conn, :forbidden)
    end
  end
end
