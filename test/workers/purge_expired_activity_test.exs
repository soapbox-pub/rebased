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
end
