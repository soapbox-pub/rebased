# Pleroma: A lightweight social networking server
# Copyright © 2017-2021 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Group.AnnouncerTest do
  use Pleroma.DataCase, async: true

  alias Pleroma.Activity
  alias Pleroma.Group
  alias Pleroma.Group.Announcer

  import Pleroma.Factory

  test "should_announce?/2 with empty addressing returns false" do
    group = insert(:group)

    object = %{
      "type" => "Note",
      "to" => [],
      "cc" => []
    }

    refute Announcer.should_announce?(group, object)
  end

  test "should_announce?/2 from a member returns true" do
    group = insert(:group)
    user = insert(:user)
    Group.add_member(group, user)

    object = %{
      "type" => "Note",
      "actor" => user.ap_id,
      "to" => [group.ap_id],
      "cc" => []
    }

    assert Announcer.should_announce?(group, object)
  end

  test "should_announce?/2 from a non-member returns false" do
    group = insert(:group)
    user = insert(:user)

    object = %{
      "type" => "Note",
      "actor" => user.ap_id,
      "to" => [group.ap_id],
      "cc" => []
    }

    refute Announcer.should_announce?(group, object)
  end

  test "announce/2 creates an Announce activity" do
    group = insert(:group)
    user = insert(:user)
    Group.add_member(group, user)

    note = %{
      "to" => [group.ap_id],
      "cc" => []
    }

    %{data: object} = insert(:note, user: user, data: note)

    {:ok, %Activity{data: activity}, _meta} = Announcer.announce(group, object)

    assert activity["type"] == "Announce"
    assert activity["actor"] == group.ap_id
    assert activity["to"] == [group.members_collection, object["actor"]]
    assert activity["cc"] == []
    assert activity["object"] == object["id"]
  end
end
