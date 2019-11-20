# Pleroma: A lightweight social networking server
# Copyright © 2017-2019 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.MastodonAPI.ScheduledActivityControllerTest do
  use Pleroma.Web.ConnCase

  alias Pleroma.Repo
  alias Pleroma.ScheduledActivity

  import Pleroma.Factory

  test "shows scheduled activities", %{conn: conn} do
    user = insert(:user)
    scheduled_activity_id1 = insert(:scheduled_activity, user: user).id |> to_string()
    scheduled_activity_id2 = insert(:scheduled_activity, user: user).id |> to_string()
    scheduled_activity_id3 = insert(:scheduled_activity, user: user).id |> to_string()
    scheduled_activity_id4 = insert(:scheduled_activity, user: user).id |> to_string()

    conn =
      conn
      |> assign(:user, user)

    # min_id
    conn_res =
      conn
      |> get("/api/v1/scheduled_statuses?limit=2&min_id=#{scheduled_activity_id1}")

    result = json_response(conn_res, 200)
    assert [%{"id" => ^scheduled_activity_id3}, %{"id" => ^scheduled_activity_id2}] = result

    # since_id
    conn_res =
      conn
      |> get("/api/v1/scheduled_statuses?limit=2&since_id=#{scheduled_activity_id1}")

    result = json_response(conn_res, 200)
    assert [%{"id" => ^scheduled_activity_id4}, %{"id" => ^scheduled_activity_id3}] = result

    # max_id
    conn_res =
      conn
      |> get("/api/v1/scheduled_statuses?limit=2&max_id=#{scheduled_activity_id4}")

    result = json_response(conn_res, 200)
    assert [%{"id" => ^scheduled_activity_id3}, %{"id" => ^scheduled_activity_id2}] = result
  end

  test "shows a scheduled activity", %{conn: conn} do
    user = insert(:user)
    scheduled_activity = insert(:scheduled_activity, user: user)

    res_conn =
      conn
      |> assign(:user, user)
      |> get("/api/v1/scheduled_statuses/#{scheduled_activity.id}")

    assert %{"id" => scheduled_activity_id} = json_response(res_conn, 200)
    assert scheduled_activity_id == scheduled_activity.id |> to_string()

    res_conn =
      conn
      |> assign(:user, user)
      |> get("/api/v1/scheduled_statuses/404")

    assert %{"error" => "Record not found"} = json_response(res_conn, 404)
  end

  test "updates a scheduled activity", %{conn: conn} do
    user = insert(:user)
    scheduled_activity = insert(:scheduled_activity, user: user)

    new_scheduled_at =
      NaiveDateTime.add(NaiveDateTime.utc_now(), :timer.minutes(120), :millisecond)

    res_conn =
      conn
      |> assign(:user, user)
      |> put("/api/v1/scheduled_statuses/#{scheduled_activity.id}", %{
        scheduled_at: new_scheduled_at
      })

    assert %{"scheduled_at" => expected_scheduled_at} = json_response(res_conn, 200)
    assert expected_scheduled_at == Pleroma.Web.CommonAPI.Utils.to_masto_date(new_scheduled_at)

    res_conn =
      conn
      |> assign(:user, user)
      |> put("/api/v1/scheduled_statuses/404", %{scheduled_at: new_scheduled_at})

    assert %{"error" => "Record not found"} = json_response(res_conn, 404)
  end

  test "deletes a scheduled activity", %{conn: conn} do
    user = insert(:user)
    scheduled_activity = insert(:scheduled_activity, user: user)

    res_conn =
      conn
      |> assign(:user, user)
      |> delete("/api/v1/scheduled_statuses/#{scheduled_activity.id}")

    assert %{} = json_response(res_conn, 200)
    assert nil == Repo.get(ScheduledActivity, scheduled_activity.id)

    res_conn =
      conn
      |> assign(:user, user)
      |> delete("/api/v1/scheduled_statuses/#{scheduled_activity.id}")

    assert %{"error" => "Record not found"} = json_response(res_conn, 404)
  end
end
