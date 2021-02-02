# Pleroma: A lightweight social networking server
# Copyright © 2017-2021 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Workers.ScheduledActivityWorkerTest do
  use Pleroma.DataCase

  alias Pleroma.ScheduledActivity
  alias Pleroma.Workers.ScheduledActivityWorker

  import Pleroma.Factory
  import ExUnit.CaptureLog

  setup do: clear_config([ScheduledActivity, :enabled])

  test "creates a status from the scheduled activity" do
    clear_config([ScheduledActivity, :enabled], true)
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

    ScheduledActivityWorker.perform(%Oban.Job{args: %{"activity_id" => scheduled_activity.id}})

    refute Repo.get(ScheduledActivity, scheduled_activity.id)
    activity = Repo.all(Pleroma.Activity) |> Enum.find(&(&1.actor == user.ap_id))
    assert Pleroma.Object.normalize(activity, fetch: false).data["content"] == "hi"
  end

  test "adds log message if ScheduledActivity isn't find" do
    clear_config([ScheduledActivity, :enabled], true)

    assert capture_log([level: :error], fn ->
             ScheduledActivityWorker.perform(%Oban.Job{args: %{"activity_id" => 42}})
           end) =~ "Couldn't find scheduled activity"
  end
end
