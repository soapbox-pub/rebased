# Pleroma: A lightweight social networking server
# Copyright © 2017-2020 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.MastodonAPI.ReportControllerTest do
  use Pleroma.Web.ConnCase

  alias Pleroma.Web.CommonAPI

  import Pleroma.Factory

  setup do: oauth_access(["write:reports"])

  setup do
    target_user = insert(:user)

    {:ok, activity} = CommonAPI.post(target_user, %{"status" => "foobar"})

    [target_user: target_user, activity: activity]
  end

  test "submit a basic report", %{conn: conn, target_user: target_user} do
    assert %{"action_taken" => false, "id" => _} =
             conn
             |> post("/api/v1/reports", %{"account_id" => target_user.id})
             |> json_response(200)
  end

  test "submit a report with statuses and comment", %{
    conn: conn,
    target_user: target_user,
    activity: activity
  } do
    assert %{"action_taken" => false, "id" => _} =
             conn
             |> post("/api/v1/reports", %{
               "account_id" => target_user.id,
               "status_ids" => [activity.id],
               "comment" => "bad status!",
               "forward" => "false"
             })
             |> json_response(200)
  end

  test "account_id is required", %{
    conn: conn,
    activity: activity
  } do
    assert %{"error" => "Valid `account_id` required"} =
             conn
             |> post("/api/v1/reports", %{"status_ids" => [activity.id]})
             |> json_response(400)
  end

  test "comment must be up to the size specified in the config", %{
    conn: conn,
    target_user: target_user
  } do
    max_size = Pleroma.Config.get([:instance, :max_report_comment_size], 1000)
    comment = String.pad_trailing("a", max_size + 1, "a")

    error = %{"error" => "Comment must be up to #{max_size} characters"}

    assert ^error =
             conn
             |> post("/api/v1/reports", %{"account_id" => target_user.id, "comment" => comment})
             |> json_response(400)
  end

  test "returns error when account is not exist", %{
    conn: conn,
    activity: activity
  } do
    conn = post(conn, "/api/v1/reports", %{"status_ids" => [activity.id], "account_id" => "foo"})

    assert json_response(conn, 400) == %{"error" => "Account not found"}
  end
end
