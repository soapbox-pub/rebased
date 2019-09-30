# Pleroma: A lightweight social networking server
# Copyright © 2017-2019 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.ScheduledActivityTest do
  use Pleroma.DataCase
  alias Pleroma.DataCase
  alias Pleroma.ScheduledActivity
  import Pleroma.Factory

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
end
