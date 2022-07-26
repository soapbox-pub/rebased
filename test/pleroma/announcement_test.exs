# Pleroma: A lightweight social networking server
# Copyright © 2017-2022 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.AnnouncementTest do
  alias Pleroma.Announcement

  use Pleroma.DataCase, async: true

  import Pleroma.Factory

  describe "list_all_visible_when/1" do
    setup do: {:ok, time: NaiveDateTime.utc_now()}

    test "with no start or end time", %{time: time} do
      _announcement = insert(:announcement)

      assert [_] = Announcement.list_all_visible_when(time)
    end

    test "with start time before current", %{time: time} do
      before_now = NaiveDateTime.add(time, -10, :second)

      _announcement = insert(:announcement, %{starts_at: before_now})

      assert [_] = Announcement.list_all_visible_when(time)
    end

    test "with start time after current", %{time: time} do
      after_now = NaiveDateTime.add(time, 10, :second)

      _announcement = insert(:announcement, %{starts_at: after_now})

      assert [] = Announcement.list_all_visible_when(time)
    end

    test "with end time after current", %{time: time} do
      after_now = NaiveDateTime.add(time, 10, :second)

      _announcement = insert(:announcement, %{ends_at: after_now})

      assert [_] = Announcement.list_all_visible_when(time)
    end

    test "with end time before current", %{time: time} do
      before_now = NaiveDateTime.add(time, -10, :second)

      _announcement = insert(:announcement, %{ends_at: before_now})

      assert [] = Announcement.list_all_visible_when(time)
    end

    test "with both start and end time", %{time: time} do
      before_now = NaiveDateTime.add(time, -10, :second)
      after_now = NaiveDateTime.add(time, 10, :second)

      _announcement = insert(:announcement, %{starts_at: before_now, ends_at: after_now})

      assert [_] = Announcement.list_all_visible_when(time)
    end

    test "with both start and end time, current not in the range", %{time: time} do
      before_now = NaiveDateTime.add(time, -10, :second)
      after_now = NaiveDateTime.add(time, 10, :second)

      _announcement = insert(:announcement, %{starts_at: after_now, ends_at: before_now})

      assert [] = Announcement.list_all_visible_when(time)
    end
  end

  describe "announcements formatting" do
    test "it formats links" do
      raw = "something on https://pleroma.social ."
      announcement = insert(:announcement, %{data: %{"content" => raw}})

      assert announcement.rendered["content"] =~ ~r(<a.+?https://pleroma.social)
      assert announcement.data["content"] == raw
    end

    test "it formats mentions" do
      user = insert(:user)
      raw = "something on @#{user.nickname} ."
      announcement = insert(:announcement, %{data: %{"content" => raw}})

      assert announcement.rendered["content"] =~ ~r(<a.+?#{user.nickname})
      assert announcement.data["content"] == raw
    end

    test "it formats tags" do
      raw = "something on #mew ."
      announcement = insert(:announcement, %{data: %{"content" => raw}})

      assert announcement.rendered["content"] =~ ~r(<a.+?#mew)
      assert announcement.data["content"] == raw
    end
  end
end
