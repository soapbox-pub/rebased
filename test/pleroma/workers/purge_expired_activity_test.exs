# Pleroma: A lightweight social networking server
# Copyright © 2017-2022 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Workers.PurgeExpiredActivityTest do
  use Pleroma.DataCase, async: true
  use Oban.Testing, repo: Pleroma.Repo

  import Pleroma.Factory

  alias Pleroma.Workers.PurgeExpiredActivity

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

  test "error if user was not found" do
    activity = insert(:note_activity)

    assert {:ok, _} =
             PurgeExpiredActivity.enqueue(%{
               activity_id: activity.id,
               expires_at: DateTime.add(DateTime.utc_now(), 3601)
             })

    user = Pleroma.User.get_by_ap_id(activity.actor)
    Pleroma.Repo.delete(user)

    assert {:error, :user_not_found} =
             perform_job(Pleroma.Workers.PurgeExpiredActivity, %{activity_id: activity.id})
  end

  test "error if actiivity was not found" do
    assert {:ok, _} =
             PurgeExpiredActivity.enqueue(%{
               activity_id: "some_id",
               expires_at: DateTime.add(DateTime.utc_now(), 3601)
             })

    assert {:error, :activity_not_found} =
             perform_job(Pleroma.Workers.PurgeExpiredActivity, %{activity_id: "some_if"})
  end
end
