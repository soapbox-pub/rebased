# Pleroma: A lightweight social networking server
# Copyright © 2017-2019 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Workers.Cron.PurgeExpiredActivitiesWorkerTest do
  use Pleroma.DataCase
  alias Pleroma.ActivityExpiration
  import Pleroma.Factory

  clear_config([ActivityExpiration, :enabled])

  test "deletes an expiration activity" do
    Pleroma.Config.put([ActivityExpiration, :enabled], true)
    activity = insert(:note_activity)

    naive_datetime =
      NaiveDateTime.add(
        NaiveDateTime.utc_now(),
        -:timer.minutes(2),
        :millisecond
      )

    expiration =
      insert(
        :expiration_in_the_past,
        %{activity_id: activity.id, scheduled_at: naive_datetime}
      )

    Pleroma.Workers.Cron.PurgeExpiredActivitiesWorker.perform(:ops, :pid)

    refute Pleroma.Repo.get(Pleroma.Activity, activity.id)
    refute Pleroma.Repo.get(Pleroma.ActivityExpiration, expiration.id)
  end
end
