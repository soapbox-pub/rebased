# Pleroma: A lightweight social networking server
# Copyright © 2017-2019 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.ThreadMuteTest do
  use Pleroma.DataCase
  import Pleroma.Web.ThreadMute

  import Pleroma.Factory

  describe "mute tests" do
    setup do
      user = insert(:user)

      activity = insert(:note_activity)

      [user: user, activity: activity]
    end

    test "add mute", %{user: user, activity: activity} do
      {:ok, _activity} = add_mute(user, activity.id)
      assert muted?(user, activity)
    end

    test "remove mute", %{user: user, activity: activity} do
      add_mute(user, activity.id)
      {:ok, _activity} = remove_mute(user, activity.id)
      refute muted?(user, activity)
    end

    test "check that mutes can't be duplicate", %{user: user, activity: activity} do
      add_mute(user, activity.id)
      assert muted?(user, activity)
      {:error, _} = add_mute(user, activity.id)
    end
  end
end
