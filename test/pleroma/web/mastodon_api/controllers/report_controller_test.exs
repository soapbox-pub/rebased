# Pleroma: A lightweight social networking server
# Copyright © 2017-2022 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.MastodonAPI.ReportControllerTest do
  use Pleroma.Web.ConnCase, async: true

  alias Pleroma.Activity
  alias Pleroma.Rule
  alias Pleroma.Web.CommonAPI

  import Pleroma.Factory

  setup do: oauth_access(["write:reports"])

  setup do
    target_user = insert(:user)

    {:ok, activity} = CommonAPI.post(target_user, %{status: "foobar"})

    [target_user: target_user, activity: activity]
  end

  test "submit a basic report", %{conn: conn, target_user: target_user} do
    assert %{"action_taken" => false, "id" => _} =
             conn
             |> put_req_header("content-type", "application/json")
             |> post("/api/v1/reports", %{"account_id" => target_user.id})
             |> json_response_and_validate_schema(200)
  end

  test "submit a report with statuses and comment", %{
    conn: conn,
    target_user: target_user,
    activity: activity
  } do
    assert %{"action_taken" => false, "id" => _} =
             conn
             |> put_req_header("content-type", "application/json")
             |> post("/api/v1/reports", %{
               "account_id" => target_user.id,
               "status_ids" => [activity.id],
               "comment" => "bad status!",
               "forward" => "false"
             })
             |> json_response_and_validate_schema(200)
  end

  test "submit a report with rule_ids", %{
    conn: conn,
    target_user: target_user
  } do
    %{id: rule_id} = Rule.create(%{text: "There are no rules"})

    assert %{"action_taken" => false, "id" => id} =
             conn
             |> put_req_header("content-type", "application/json")
             |> post("/api/v1/reports", %{
               "account_id" => target_user.id,
               "forward" => "false",
               "rule_ids" => [rule_id]
             })
             |> json_response_and_validate_schema(200)

    assert %Activity{data: %{"rules" => [^rule_id]}} = Activity.get_report(id)
  end

  test "account_id is required", %{
    conn: conn,
    activity: activity
  } do
    assert %{"error" => "Missing field: account_id."} =
             conn
             |> put_req_header("content-type", "application/json")
             |> post("/api/v1/reports", %{"status_ids" => [activity.id]})
             |> json_response_and_validate_schema(400)
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
             |> put_req_header("content-type", "application/json")
             |> post("/api/v1/reports", %{"account_id" => target_user.id, "comment" => comment})
             |> json_response_and_validate_schema(400)
  end

  test "returns error when account is not exist", %{
    conn: conn,
    activity: activity
  } do
    conn =
      conn
      |> put_req_header("content-type", "application/json")
      |> post("/api/v1/reports", %{"status_ids" => [activity.id], "account_id" => "foo"})

    assert json_response_and_validate_schema(conn, 400) == %{"error" => "Account not found"}
  end

  test "doesn't fail if an admin has no email", %{conn: conn, target_user: target_user} do
    insert(:user, %{is_admin: true, email: nil})

    assert %{"action_taken" => false, "id" => _} =
             conn
             |> put_req_header("content-type", "application/json")
             |> post("/api/v1/reports", %{"account_id" => target_user.id})
             |> json_response_and_validate_schema(200)
  end
end
