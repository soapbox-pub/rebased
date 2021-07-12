# Pleroma: A lightweight social networking server
# Copyright © 2017-2021 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Group.PrivacyTest do
  use Pleroma.DataCase, async: true

  alias Pleroma.Group
  alias Pleroma.Group.Privacy

  import Pleroma.Factory

  @public_uri "https://www.w3.org/ns/activitystreams#Public"

  describe "matches_privacy?/2 with a public group" do
    test "returns true for everything" do
      group = insert(:group, privacy: "public")

      object = %{
        "to" => [@public_uri],
        "cc" => [
          "https://mushroom.kingdom/users/mario/followers",
          "https://mushroom.kingdom/users/luigi"
        ]
      }

      assert Privacy.matches_privacy?(group, object)
    end
  end

  describe "matches_privacy?/2 with a members_only group" do
    test "reject messages with public URI" do
      group = insert(:group, privacy: "members_only")

      refute Privacy.matches_privacy?(group, %{"to" => [@public_uri]})
      refute Privacy.matches_privacy?(group, %{"cc" => [@public_uri]})
      refute Privacy.matches_privacy?(group, %{"bcc" => [@public_uri]})
    end

    test "rejects messages to non-members" do
      group = insert(:group, privacy: "members_only")
      user = insert(:user)

      refute Privacy.matches_privacy?(group, %{"to" => [user.ap_id]})
      refute Privacy.matches_privacy?(group, %{"cc" => [user.ap_id]})
      refute Privacy.matches_privacy?(group, %{"bcc" => [user.ap_id]})
    end

    test "accepts messages to members" do
      group = insert(:group, privacy: "members_only")
      user = insert(:user)
      Group.add_member(group, user)

      assert Privacy.matches_privacy?(group, %{"to" => [user.ap_id]})
      assert Privacy.matches_privacy?(group, %{"cc" => [user.ap_id]})
      assert Privacy.matches_privacy?(group, %{"bcc" => [user.ap_id]})
    end

    test "accepts messages to group" do
      group = insert(:group, privacy: "members_only")

      assert Privacy.matches_privacy?(group, %{"to" => [group.ap_id]})
      assert Privacy.matches_privacy?(group, %{"cc" => [group.ap_id]})
      assert Privacy.matches_privacy?(group, %{"bcc" => [group.ap_id]})
    end

    test "rejects messages to members' followers" do
      group = insert(:group, privacy: "members_only")
      %{follower_address: follower_address} = user = insert(:user)
      Group.add_member(group, user)

      refute Privacy.matches_privacy?(group, %{"to" => [follower_address]})
      refute Privacy.matches_privacy?(group, %{"cc" => [follower_address]})
      refute Privacy.matches_privacy?(group, %{"bcc" => [follower_address]})
    end

    test "rejects messages to group's members" do
      %{members_collection: members_collection} = group = insert(:group, privacy: "members_only")

      refute Privacy.matches_privacy?(group, %{"to" => [members_collection]})
      refute Privacy.matches_privacy?(group, %{"cc" => [members_collection]})
      refute Privacy.matches_privacy?(group, %{"bcc" => [members_collection]})
    end
  end

  test "is_members_only?" do
    group = insert(:group, privacy: "members_only")
    user = insert(:user)
    Group.add_member(group, user)

    assert Privacy.is_members_only?(insert(:note, data: %{"to" => [group.ap_id]}))
    assert Privacy.is_members_only?(insert(:note, data: %{"to" => [group.ap_id, user.ap_id]}))

    assert Privacy.is_members_only?(
             insert(:note, data: %{"to" => [group.ap_id], "cc" => [user.ap_id]})
           )

    assert Privacy.is_members_only?(
             insert(:note, data: %{"to" => [group.ap_id], "bcc" => [user.ap_id]})
           )

    refute Privacy.is_members_only?(insert(:note, data: %{"to" => [group.ap_id, @public_uri]}))

    refute Privacy.is_members_only?(
             insert(:note, data: %{"to" => [group.ap_id, insert(:user).ap_id]})
           )

    refute Privacy.is_members_only?(
             insert(:note, data: %{"to" => [group.ap_id, "https://invalid.id/123"]})
           )

    refute Privacy.is_members_only?(
             insert(:note, data: %{"to" => [group.ap_id], "cc" => [insert(:user).ap_id]})
           )

    refute Privacy.is_members_only?(
             insert(:note, data: %{"to" => [group.ap_id], "bcc" => [insert(:user).ap_id]})
           )

    refute Privacy.is_members_only?(insert(:note, data: %{"to" => [], "cc" => [group.ap_id]}))
    refute Privacy.is_members_only?(insert(:note, data: %{"to" => [], "bcc" => [group.ap_id]}))
    refute Privacy.is_members_only?(insert(:note, data: %{"to" => []}))

    assert Privacy.is_members_only?(
             insert(:note_activity, note: insert(:note, data: %{"to" => [group.ap_id]}))
           )
  end
end
