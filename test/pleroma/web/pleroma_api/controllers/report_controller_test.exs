# Pleroma: A lightweight social networking server
# Copyright © 2017-2021 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.PleromaAPI.ReportControllerTest do
  use Pleroma.Web.ConnCase, async: true

  import Pleroma.Factory

  alias Pleroma.Web.CommonAPI

  describe "GET /api/v0/pleroma/reports" do
    test "returns list of own reports" do
      %{conn: reporter_conn, user: reporter} = oauth_access(["read:reports"])
      %{conn: reported_conn, user: reported} = oauth_access(["read:reports"])
      activity = insert(:note_activity, user: reported)

      {:ok, %{id: report_id}} =
        CommonAPI.report(reporter, %{
          account_id: reported.id,
          comment: "You stole my sandwich!",
          status_ids: [activity.id]
        })

      assert reported_response =
               reported_conn
               |> get("/api/v0/pleroma/reports")
               |> json_response_and_validate_schema(:ok)

      assert reported_response == %{"reports" => [], "total" => 0}

      assert reporter_response =
               reporter_conn
               |> get("/api/v0/pleroma/reports")
               |> json_response_and_validate_schema(:ok)

      assert %{"reports" => [report], "total" => 1} = reporter_response
      assert report["id"] == report_id
      refute report["notes"]
    end
  end

  describe "GET /api/v0/pleroma/reports/:id" do
    test "returns report by its id" do
      %{conn: reporter_conn, user: reporter} = oauth_access(["read:reports"])
      %{conn: reported_conn, user: reported} = oauth_access(["read:reports"])
      activity = insert(:note_activity, user: reported)

      {:ok, %{id: report_id}} =
        CommonAPI.report(reporter, %{
          account_id: reported.id,
          comment: "You stole my sandwich!",
          status_ids: [activity.id]
        })

      assert reported_conn
             |> get("/api/v0/pleroma/reports/#{report_id}")
             |> json_response_and_validate_schema(:not_found)

      assert response =
               reporter_conn
               |> get("/api/v0/pleroma/reports/#{report_id}")
               |> json_response_and_validate_schema(:ok)

      assert response["id"] == report_id
      refute response["notes"]
    end

    test "returns 404 when report id is invalid" do
      %{conn: conn, user: _user} = oauth_access(["read:reports"])

      assert response =
               conn
               |> get("/api/v0/pleroma/reports/0")
               |> json_response_and_validate_schema(:not_found)

      assert response == %{"error" => "Record not found"}
    end
  end
end
