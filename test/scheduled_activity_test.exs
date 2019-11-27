# Pleroma: A lightweight social networking server
# Copyright © 2017-2019 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.ScheduledActivityTest do
  use Pleroma.DataCase
  alias Pleroma.DataCase
  alias Pleroma.ScheduledActivity
  import Pleroma.Factory

  clear_config([ScheduledActivity, :enabled])

  setup context do
    DataCase.ensure_local_uploader(context)
  end

  describe "creation" do
    test "when daily user limit is exceeded" do
      user = insert(:user)

      today =
        NaiveDateTime.utc_now()
        |> NaiveDateTime.add(:timer.minutes(6), :millisecond)
        |> NaiveDateTime.to_iso8601()

      attrs = %{params: %{}, scheduled_at: today}
      {:ok, _} = ScheduledActivity.create(user, attrs)
      {:ok, _} = ScheduledActivity.create(user, attrs)
      {:error, changeset} = ScheduledActivity.create(user, attrs)
      assert changeset.errors == [scheduled_at: {"daily limit exceeded", []}]
    end

    test "when total user limit is exceeded" do
      user = insert(:user)

      today =
        NaiveDateTime.utc_now()
        |> NaiveDateTime.add(:timer.minutes(6), :millisecond)
        |> NaiveDateTime.to_iso8601()

      tomorrow =
        NaiveDateTime.utc_now()
        |> NaiveDateTime.add(:timer.hours(36), :millisecond)
        |> NaiveDateTime.to_iso8601()

      {:ok, _} = ScheduledActivity.create(user, %{params: %{}, scheduled_at: today})
      {:ok, _} = ScheduledActivity.create(user, %{params: %{}, scheduled_at: today})
      {:ok, _} = ScheduledActivity.create(user, %{params: %{}, scheduled_at: tomorrow})
      {:error, changeset} = ScheduledActivity.create(user, %{params: %{}, scheduled_at: tomorrow})
      assert changeset.errors == [scheduled_at: {"total limit exceeded", []}]
    end

    test "when scheduled_at is earlier than 5 minute from now" do
      user = insert(:user)

      scheduled_at =
        NaiveDateTime.utc_now()
        |> NaiveDateTime.add(:timer.minutes(4), :millisecond)
        |> NaiveDateTime.to_iso8601()

      attrs = %{params: %{}, scheduled_at: scheduled_at}
      {:error, changeset} = ScheduledActivity.create(user, attrs)
      assert changeset.errors == [scheduled_at: {"must be at least 5 minutes from now", []}]
    end
  end

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
