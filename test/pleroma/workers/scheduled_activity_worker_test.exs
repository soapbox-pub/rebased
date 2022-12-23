# Pleroma: A lightweight social networking server
# Copyright © 2017-2022 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Workers.ScheduledActivityWorkerTest do
  use Pleroma.DataCase

  alias Pleroma.ScheduledActivity
  alias Pleroma.Workers.ScheduledActivityWorker

  import Pleroma.Factory
  import ExUnit.CaptureLog

  setup do: clear_config([ScheduledActivity, :enabled], true)

  test "creates a status from the scheduled activity" do
    user = insert(:user)

    naive_datetime =
      NaiveDateTime.add(
        NaiveDateTime.utc_now(),
        -:timer.minutes(2),
        :millisecond
      )

    scheduled_activity =
      insert(
        :scheduled_activity,
        scheduled_at: naive_datetime,
        user: user,
        params: %{status: "hi"}
      )

    {:ok, %{id: activity_id}} =
      ScheduledActivityWorker.perform(%Oban.Job{args: %{"activity_id" => scheduled_activity.id}})

    refute Repo.get(ScheduledActivity, scheduled_activity.id)

    object =
      Pleroma.Activity
      |> Repo.get(activity_id)
      |> Pleroma.Object.normalize()

    assert object.data["content"] == "hi"
  end

  test "error message for non-existent scheduled activity" do
    assert capture_log([level: :error], fn ->
             ScheduledActivityWorker.perform(%Oban.Job{args: %{"activity_id" => 42}})
           end) =~ "Couldn't find scheduled activity: 42"
  end
end
