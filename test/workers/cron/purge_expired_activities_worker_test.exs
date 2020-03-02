# Pleroma: A lightweight social networking server
# Copyright © 2017-2020 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Workers.Cron.PurgeExpiredActivitiesWorkerTest do
  use Pleroma.DataCase

  alias Pleroma.ActivityExpiration
  alias Pleroma.Workers.Cron.PurgeExpiredActivitiesWorker

  import Pleroma.Factory
  import ExUnit.CaptureLog

  clear_config([ActivityExpiration, :enabled])
  clear_config([:instance, :rewrite_policy])

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

  test "works with ActivityExpirationPolicy" do
    Pleroma.Config.put([ActivityExpiration, :enabled], true)

    Pleroma.Config.put(
      [:instance, :rewrite_policy],
      Pleroma.Web.ActivityPub.MRF.ActivityExpirationPolicy
    )

    user = insert(:user)

    days = Pleroma.Config.get([:mrf_activity_expiration, :days], 365)

    {:ok, %{id: id} = activity} = Pleroma.Web.CommonAPI.post(user, %{"status" => "cofe"})

    past_date =
      NaiveDateTime.utc_now() |> Timex.shift(days: -days) |> NaiveDateTime.truncate(:second)

    activity
    |> Repo.preload(:expiration)
    |> Map.get(:expiration)
    |> Ecto.Changeset.change(%{scheduled_at: past_date})
    |> Repo.update!()

    Pleroma.Workers.Cron.PurgeExpiredActivitiesWorker.perform(:ops, :pid)

    assert [%{data: %{"type" => "Delete", "deleted_activity_id" => ^id}}] =
             Pleroma.Repo.all(Pleroma.Activity)
  end

  describe "delete_activity/1" do
    test "adds log message if activity isn't find" do
      assert capture_log([level: :error], fn ->
               PurgeExpiredActivitiesWorker.delete_activity(%ActivityExpiration{
                 activity_id: "test-activity"
               })
             end) =~ "Couldn't delete expired activity: not found activity"
    end

    test "adds log message if actor isn't find" do
      assert capture_log([level: :error], fn ->
               PurgeExpiredActivitiesWorker.delete_activity(%ActivityExpiration{
                 activity_id: "test-activity"
               })
             end) =~ "Couldn't delete expired activity: not found activity"
    end
  end
end
