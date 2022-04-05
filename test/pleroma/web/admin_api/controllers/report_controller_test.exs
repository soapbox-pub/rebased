# Pleroma: A lightweight social networking server
# Copyright © 2017-2022 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.AdminAPI.ReportControllerTest do
  use Pleroma.Web.ConnCase, async: true

  import Pleroma.Factory

  alias Pleroma.Activity
  alias Pleroma.ModerationLog
  alias Pleroma.Repo
  alias Pleroma.ReportNote
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

  describe "GET /api/pleroma/admin/reports/:id" do
    test "returns report by its id", %{conn: conn} do
      [reporter, target_user] = insert_pair(:user)
      activity = insert(:note_activity, user: target_user)

      {:ok, %{id: report_id}} =
        CommonAPI.report(reporter, %{
          account_id: target_user.id,
          comment: "I feel offended",
          status_ids: [activity.id]
        })

      conn
      |> put_req_header("content-type", "application/json")
      |> post("/api/pleroma/admin/reports/#{report_id}/notes", %{
        content: "this is an admin note"
      })

      response =
        conn
        |> get("/api/pleroma/admin/reports/#{report_id}")
        |> json_response_and_validate_schema(:ok)

      assert response["id"] == report_id

      [notes] = response["notes"]
      assert notes["content"] == "this is an admin note"
    end

    test "returns 404 when report id is invalid", %{conn: conn} do
      conn = get(conn, "/api/pleroma/admin/reports/test")

      assert json_response_and_validate_schema(conn, :not_found) == %{"error" => "Not found"}
    end
  end

  describe "PATCH /api/pleroma/admin/reports" do
    setup do
      [reporter, target_user] = insert_pair(:user)
      activity = insert(:note_activity, user: target_user)

      {:ok, %{id: report_id}} =
        CommonAPI.report(reporter, %{
          account_id: target_user.id,
          comment: "I feel offended",
          status_ids: [activity.id]
        })

      {:ok, %{id: second_report_id}} =
        CommonAPI.report(reporter, %{
          account_id: target_user.id,
          comment: "I feel very offended",
          status_ids: [activity.id]
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
        |> put_req_header("content-type", "application/json")
        |> patch("/api/pleroma/admin/reports", %{
          "reports" => [%{"state" => "resolved", "id" => id}]
        })
        |> json_response_and_validate_schema(403)

      assert response == %{
               "error" => "Insufficient permissions: admin:write:reports."
             }

      conn
      |> assign(:token, write_token)
      |> put_req_header("content-type", "application/json")
      |> patch("/api/pleroma/admin/reports", %{
        "reports" => [%{"state" => "resolved", "id" => id}]
      })
      |> json_response_and_validate_schema(:no_content)
    end

    test "mark report as resolved", %{conn: conn, id: id, admin: admin} do
      conn
      |> put_req_header("content-type", "application/json")
      |> patch("/api/pleroma/admin/reports", %{
        "reports" => [
          %{"state" => "resolved", "id" => id}
        ]
      })
      |> json_response_and_validate_schema(:no_content)

      activity = Activity.get_by_id_with_user_actor(id)
      assert activity.data["state"] == "resolved"

      log_entry = Repo.one(ModerationLog)

      assert ModerationLog.get_log_entry_message(log_entry) ==
               "@#{admin.nickname} updated report ##{id} (on user @#{activity.user_actor.nickname}) with 'resolved' state"
    end

    test "closes report", %{conn: conn, id: id, admin: admin} do
      conn
      |> put_req_header("content-type", "application/json")
      |> patch("/api/pleroma/admin/reports", %{
        "reports" => [
          %{"state" => "closed", "id" => id}
        ]
      })
      |> json_response_and_validate_schema(:no_content)

      activity = Activity.get_by_id_with_user_actor(id)
      assert activity.data["state"] == "closed"

      log_entry = Repo.one(ModerationLog)

      assert ModerationLog.get_log_entry_message(log_entry) ==
               "@#{admin.nickname} updated report ##{id} (on user @#{activity.user_actor.nickname}) with 'closed' state"
    end

    test "returns 400 when state is unknown", %{conn: conn, id: id} do
      conn =
        conn
        |> put_req_header("content-type", "application/json")
        |> patch("/api/pleroma/admin/reports", %{
          "reports" => [
            %{"state" => "test", "id" => id}
          ]
        })

      assert "Unsupported state" =
               hd(json_response_and_validate_schema(conn, :bad_request))["error"]
    end

    test "returns 404 when report is not exist", %{conn: conn} do
      conn =
        conn
        |> put_req_header("content-type", "application/json")
        |> patch("/api/pleroma/admin/reports", %{
          "reports" => [
            %{"state" => "closed", "id" => "test"}
          ]
        })

      assert hd(json_response_and_validate_schema(conn, :bad_request))["error"] == "not_found"
    end

    test "updates state of multiple reports", %{
      conn: conn,
      id: id,
      admin: admin,
      second_report_id: second_report_id
    } do
      conn
      |> put_req_header("content-type", "application/json")
      |> patch("/api/pleroma/admin/reports", %{
        "reports" => [
          %{"state" => "resolved", "id" => id},
          %{"state" => "closed", "id" => second_report_id}
        ]
      })
      |> json_response_and_validate_schema(:no_content)

      activity = Activity.get_by_id_with_user_actor(id)
      second_activity = Activity.get_by_id_with_user_actor(second_report_id)
      assert activity.data["state"] == "resolved"
      assert second_activity.data["state"] == "closed"

      [first_log_entry, second_log_entry] = Repo.all(ModerationLog)

      assert ModerationLog.get_log_entry_message(first_log_entry) ==
               "@#{admin.nickname} updated report ##{id} (on user @#{activity.user_actor.nickname}) with 'resolved' state"

      assert ModerationLog.get_log_entry_message(second_log_entry) ==
               "@#{admin.nickname} updated report ##{second_report_id} (on user @#{second_activity.user_actor.nickname}) with 'closed' state"
    end
  end

  describe "GET /api/pleroma/admin/reports" do
    test "returns empty response when no reports created", %{conn: conn} do
      response =
        conn
        |> get(report_path(conn, :index))
        |> json_response_and_validate_schema(:ok)

      assert Enum.empty?(response["reports"])
      assert response["total"] == 0
    end

    test "returns reports", %{conn: conn} do
      [reporter, target_user] = insert_pair(:user)
      activity = insert(:note_activity, user: target_user)

      {:ok, %{id: report_id}} =
        CommonAPI.report(reporter, %{
          account_id: target_user.id,
          comment: "I feel offended",
          status_ids: [activity.id]
        })

      response =
        conn
        |> get(report_path(conn, :index))
        |> json_response_and_validate_schema(:ok)

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
          account_id: target_user.id,
          comment: "I feel offended",
          status_ids: [activity.id]
        })

      {:ok, %{id: second_report_id}} =
        CommonAPI.report(reporter, %{
          account_id: target_user.id,
          comment: "I don't like this user"
        })

      CommonAPI.update_report_state(second_report_id, "closed")

      response =
        conn
        |> get(report_path(conn, :index, %{state: "open"}))
        |> json_response_and_validate_schema(:ok)

      assert [open_report] = response["reports"]

      assert length(response["reports"]) == 1
      assert open_report["id"] == first_report_id

      assert response["total"] == 1

      response =
        conn
        |> get(report_path(conn, :index, %{state: "closed"}))
        |> json_response_and_validate_schema(:ok)

      assert [closed_report] = response["reports"]

      assert length(response["reports"]) == 1
      assert closed_report["id"] == second_report_id

      assert response["total"] == 1

      assert %{"total" => 0, "reports" => []} ==
               conn
               |> get(report_path(conn, :index, %{state: "resolved"}))
               |> json_response_and_validate_schema(:ok)
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
               %{"error" => "User is not a staff member."}
    end

    test "returns 403 when requested by anonymous" do
      conn = get(build_conn(), "/api/pleroma/admin/reports")

      assert json_response(conn, :forbidden) == %{
               "error" => "Invalid credentials."
             }
    end
  end

  describe "POST /api/pleroma/admin/reports/:id/notes" do
    setup %{conn: conn, admin: admin} do
      [reporter, target_user] = insert_pair(:user)
      activity = insert(:note_activity, user: target_user)

      {:ok, %{id: report_id}} =
        CommonAPI.report(reporter, %{
          account_id: target_user.id,
          comment: "I feel offended",
          status_ids: [activity.id]
        })

      conn
      |> put_req_header("content-type", "application/json")
      |> post("/api/pleroma/admin/reports/#{report_id}/notes", %{
        content: "this is disgusting!"
      })

      conn
      |> put_req_header("content-type", "application/json")
      |> post("/api/pleroma/admin/reports/#{report_id}/notes", %{
        content: "this is disgusting2!"
      })

      %{
        admin_id: admin.id,
        report_id: report_id
      }
    end

    test "it creates report note", %{admin_id: admin_id, report_id: report_id} do
      assert [note, _] = Repo.all(ReportNote)

      assert %{
               activity_id: ^report_id,
               content: "this is disgusting!",
               user_id: ^admin_id
             } = note
    end

    test "it returns reports with notes", %{conn: conn, admin: admin} do
      conn = get(conn, "/api/pleroma/admin/reports")

      response = json_response_and_validate_schema(conn, 200)
      notes = hd(response["reports"])["notes"]
      [note, _] = notes

      assert note["user"]["nickname"] == admin.nickname
      # We use '=~' because the order of the notes isn't guaranteed
      assert note["content"] =~ "this is disgusting"
      assert note["created_at"]
      assert response["total"] == 1
    end

    test "it deletes the note", %{conn: conn, report_id: report_id} do
      assert ReportNote |> Repo.all() |> length() == 2
      assert [note, _] = Repo.all(ReportNote)

      delete(conn, "/api/pleroma/admin/reports/#{report_id}/notes/#{note.id}")

      assert ReportNote |> Repo.all() |> length() == 1
    end
  end
end
