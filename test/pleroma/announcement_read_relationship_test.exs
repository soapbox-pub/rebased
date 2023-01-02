# Pleroma: A lightweight social networking server
# Copyright © 2017-2022 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.AnnouncementReadRelationshipTest do
  alias Pleroma.AnnouncementReadRelationship

  use Pleroma.DataCase, async: true

  import Pleroma.Factory

  setup do
    {:ok, user: insert(:user), announcement: insert(:announcement)}
  end

  describe "mark_read/2" do
    test "should insert relationship", %{user: user, announcement: announcement} do
      {:ok, _} = AnnouncementReadRelationship.mark_read(user, announcement)

      assert AnnouncementReadRelationship.exists?(user, announcement)
    end
  end

  describe "mark_unread/2" do
    test "should delete relationship", %{user: user, announcement: announcement} do
      {:ok, _} = AnnouncementReadRelationship.mark_read(user, announcement)

      assert :ok = AnnouncementReadRelationship.mark_unread(user, announcement)
      refute AnnouncementReadRelationship.exists?(user, announcement)
    end

    test "should not fail if relationship does not exist", %{
      user: user,
      announcement: announcement
    } do
      assert :ok = AnnouncementReadRelationship.mark_unread(user, announcement)
      refute AnnouncementReadRelationship.exists?(user, announcement)
    end
  end
end
