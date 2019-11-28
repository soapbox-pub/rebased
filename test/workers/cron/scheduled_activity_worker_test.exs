# Pleroma: A lightweight social networking server
# Copyright © 2017-2019 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Workers.Cron.ScheduledActivityWorkerTest do
  use Pleroma.DataCase
  alias Pleroma.ScheduledActivity
  import Pleroma.Factory

  clear_config([ScheduledActivity, :enabled])

  test "creates a status from the scheduled activity" do
    Pleroma.Config.put([ScheduledActivity, :enabled], true)
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

    Pleroma.Workers.Cron.ScheduledActivityWorker.perform(:opts, :pid)

    refute Repo.get(ScheduledActivity, scheduled_activity.id)
    activity = Repo.all(Pleroma.Activity) |> Enum.find(&(&1.actor == user.ap_id))
    assert Pleroma.Object.normalize(activity).data["content"] == "hi"
  end
end
