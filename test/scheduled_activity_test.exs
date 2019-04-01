# Pleroma: A lightweight social networking server
# Copyright © 2017-2018 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.ScheduledActivityTest do
  use Pleroma.DataCase
  alias Pleroma.Config
  alias Pleroma.DataCase
  alias Pleroma.ScheduledActivity
  alias Pleroma.Web.ActivityPub.ActivityPub
  import Pleroma.Factory

  setup context do
    Config.put([ScheduledActivity, :daily_user_limit], 2)
    Config.put([ScheduledActivity, :total_user_limit], 3)
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
        |> NaiveDateTime.add(:timer.hours(24), :millisecond)
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

    test "excludes attachments belonging to another user" do
      user = insert(:user)
      another_user = insert(:user)

      scheduled_at =
        NaiveDateTime.utc_now()
        |> NaiveDateTime.add(:timer.minutes(10), :millisecond)
        |> NaiveDateTime.to_iso8601()

      file = %Plug.Upload{
        content_type: "image/jpg",
        path: Path.absname("test/fixtures/image.jpg"),
        filename: "an_image.jpg"
      }

      {:ok, user_upload} = ActivityPub.upload(file, actor: user.ap_id)
      {:ok, another_user_upload} = ActivityPub.upload(file, actor: another_user.ap_id)

      media_ids = [user_upload.id, another_user_upload.id]
      attrs = %{params: %{"media_ids" => media_ids}, scheduled_at: scheduled_at}
      {:ok, scheduled_activity} = ScheduledActivity.create(user, attrs)
      assert to_string(user_upload.id) in scheduled_activity.params["media_ids"]
      refute to_string(another_user_upload.id) in scheduled_activity.params["media_ids"]
    end
  end
end
