# Pleroma: A lightweight social networking server
# Copyright © 2017-2020 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Workers.PurgeExpiredActivityTest do
  use Pleroma.DataCase, async: true
  use Oban.Testing, repo: Pleroma.Repo

  import Pleroma.Factory

  alias Pleroma.Workers.PurgeExpiredActivity

  test "denies expirations that don't live long enough" do
    activity = insert(:note_activity)

    assert {:error, :expiration_too_close} =
             PurgeExpiredActivity.enqueue(%{
               activity_id: activity.id,
               expires_at: DateTime.utc_now()
             })

    refute_enqueued(
      worker: Pleroma.Workers.PurgeExpiredActivity,
      args: %{activity_id: activity.id}
    )
  end

  test "enqueue job" do
    activity = insert(:note_activity)

    assert {:ok, _} =
             PurgeExpiredActivity.enqueue(%{
               activity_id: activity.id,
               expires_at: DateTime.add(DateTime.utc_now(), 3601)
             })

    assert_enqueued(
      worker: Pleroma.Workers.PurgeExpiredActivity,
      args: %{activity_id: activity.id}
    )

    assert {:ok, _} =
             perform_job(Pleroma.Workers.PurgeExpiredActivity, %{activity_id: activity.id})

    assert %Oban.Job{} = Pleroma.Workers.PurgeExpiredActivity.get_expiration(activity.id)
  end

  test "don't delete pinned posts, schedule deletion on next day" do
    activity = insert(:note_activity)

    assert {:ok, _} =
             PurgeExpiredActivity.enqueue(%{
               activity_id: activity.id,
               expires_at: DateTime.utc_now(),
               validate: false
             })

    user = Pleroma.User.get_by_ap_id(activity.actor)
    {:ok, activity} = Pleroma.Web.CommonAPI.pin(activity.id, user)

    assert %{success: 1, failure: 0} ==
             Oban.drain_queue(queue: :activity_expiration, with_scheduled: true)

    job = Pleroma.Workers.PurgeExpiredActivity.get_expiration(activity.id)

    assert DateTime.diff(job.scheduled_at, DateTime.add(DateTime.utc_now(), 24 * 3600)) in [0, 1]
  end
end
