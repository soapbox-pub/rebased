# Pleroma: A lightweight social networking server
# Copyright © 2017-2022 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.MastodonAPI.ScheduledActivityControllerTest do
  use Oban.Testing, repo: Pleroma.Repo
  use Pleroma.Web.ConnCase, async: true

  alias Pleroma.Repo
  alias Pleroma.ScheduledActivity
  alias Pleroma.UnstubbedConfigMock, as: ConfigMock

  import Ecto.Query
  import Mox
  import Pleroma.Factory

  setup do
    ConfigMock
    |> stub(:get, fn
      [ScheduledActivity, :enabled] -> true
      path -> Pleroma.Test.StaticConfig.get(path)
    end)

    :ok
  end

  test "shows scheduled activities" do
    %{user: user, conn: conn} = oauth_access(["read:statuses"])

    scheduled_activity_id1 = insert(:scheduled_activity, user: user).id |> to_string()
    scheduled_activity_id2 = insert(:scheduled_activity, user: user).id |> to_string()
    scheduled_activity_id3 = insert(:scheduled_activity, user: user).id |> to_string()
    scheduled_activity_id4 = insert(:scheduled_activity, user: user).id |> to_string()

    # min_id
    conn_res = get(conn, "/api/v1/scheduled_statuses?limit=2&min_id=#{scheduled_activity_id1}")

    result = json_response_and_validate_schema(conn_res, 200)
    assert [%{"id" => ^scheduled_activity_id3}, %{"id" => ^scheduled_activity_id2}] = result

    # since_id
    conn_res = get(conn, "/api/v1/scheduled_statuses?limit=2&since_id=#{scheduled_activity_id1}")

    result = json_response_and_validate_schema(conn_res, 200)
    assert [%{"id" => ^scheduled_activity_id4}, %{"id" => ^scheduled_activity_id3}] = result

    # max_id
    conn_res = get(conn, "/api/v1/scheduled_statuses?limit=2&max_id=#{scheduled_activity_id4}")

    result = json_response_and_validate_schema(conn_res, 200)
    assert [%{"id" => ^scheduled_activity_id3}, %{"id" => ^scheduled_activity_id2}] = result
  end

  test "shows a scheduled activity" do
    %{user: user, conn: conn} = oauth_access(["read:statuses"])
    scheduled_activity = insert(:scheduled_activity, user: user)

    res_conn = get(conn, "/api/v1/scheduled_statuses/#{scheduled_activity.id}")

    assert %{"id" => scheduled_activity_id} = json_response_and_validate_schema(res_conn, 200)
    assert scheduled_activity_id == scheduled_activity.id |> to_string()

    res_conn = get(conn, "/api/v1/scheduled_statuses/404")

    assert %{"error" => "Record not found"} = json_response_and_validate_schema(res_conn, 404)
  end

  test "updates a scheduled activity" do
    %{user: user, conn: conn} = oauth_access(["write:statuses"])

    scheduled_at = Timex.shift(NaiveDateTime.utc_now(), minutes: 60)

    {:ok, scheduled_activity} =
      ScheduledActivity.create(
        user,
        %{
          scheduled_at: scheduled_at,
          params: build(:note).data
        }
      )

    job = Repo.one(from(j in Oban.Job, where: j.queue == "federator_outgoing"))

    assert job.args == %{"activity_id" => scheduled_activity.id}
    assert DateTime.truncate(job.scheduled_at, :second) == to_datetime(scheduled_at)

    new_scheduled_at =
      NaiveDateTime.utc_now()
      |> Timex.shift(minutes: 120)
      |> Timex.format!("%Y-%m-%dT%H:%M:%S.%fZ", :strftime)

    res_conn =
      conn
      |> put_req_header("content-type", "application/json")
      |> put("/api/v1/scheduled_statuses/#{scheduled_activity.id}", %{
        scheduled_at: new_scheduled_at
      })

    assert %{"scheduled_at" => expected_scheduled_at} =
             json_response_and_validate_schema(res_conn, 200)

    assert expected_scheduled_at == Pleroma.Web.CommonAPI.Utils.to_masto_date(new_scheduled_at)
    job = refresh_record(job)

    assert DateTime.truncate(job.scheduled_at, :second) == to_datetime(new_scheduled_at)

    res_conn =
      conn
      |> put_req_header("content-type", "application/json")
      |> put("/api/v1/scheduled_statuses/404", %{scheduled_at: new_scheduled_at})

    assert %{"error" => "Record not found"} = json_response_and_validate_schema(res_conn, 404)
  end

  test "deletes a scheduled activity" do
    %{user: user, conn: conn} = oauth_access(["write:statuses"])
    scheduled_at = Timex.shift(NaiveDateTime.utc_now(), minutes: 60)

    {:ok, scheduled_activity} =
      ScheduledActivity.create(
        user,
        %{
          scheduled_at: scheduled_at,
          params: build(:note).data
        }
      )

    assert_enqueued(
      worker: Pleroma.Workers.ScheduledActivityWorker,
      args: %{"activity_id" => scheduled_activity.id},
      queue: :federator_outgoing
    )

    res_conn =
      conn
      |> assign(:user, user)
      |> delete("/api/v1/scheduled_statuses/#{scheduled_activity.id}")

    assert %{} = json_response_and_validate_schema(res_conn, 200)
    refute Repo.get(ScheduledActivity, scheduled_activity.id)

    refute_enqueued(
      worker: Pleroma.Workers.ScheduledActivityWorker,
      args: %{"activity_id" => scheduled_activity.id}
    )

    res_conn =
      conn
      |> assign(:user, user)
      |> delete("/api/v1/scheduled_statuses/#{scheduled_activity.id}")

    assert %{"error" => "Record not found"} = json_response_and_validate_schema(res_conn, 404)
  end
end
