# Pleroma: A lightweight social networking server
# Copyright © 2017-2021 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.GroupTest do
  use Pleroma.DataCase, async: true

  alias Pleroma.Group
  alias Pleroma.Repo

  import Pleroma.Factory

  test "a user can create a group" do
    user = insert(:user)
    {:ok, group} = Group.create(%{owner_id: user.id, name: "cofe", description: "corndog"})
    group = Repo.preload(group, :user)

    assert group.user.actor_type == "Group"
    assert group.owner_id == user.id
    assert group.name == "cofe"
    assert group.description == "corndog"

    # Deleting the owner does not delete the group, just orphans it
    Repo.delete(user)

    group =
      Repo.get(Group, group.id)
      |> Repo.preload(:user)

    assert group.owner_id == nil

    # Deleting the group user deletes the group
    Repo.delete(group.user)
    refute Repo.get(Group, group.id)
  end

  test "group members can be seen and added" do
    user = insert(:user)
    other_user = insert(:user)
    third_user = insert(:user)

    {:ok, group} = Group.create(%{owner_id: user.id, name: "cofe", description: "corndog"})

    assert [] == Group.members(group)

    {:ok, group} = Group.add_member(group, other_user)
    assert [other_user] == Group.members(group)

    assert Group.is_member?(group, other_user)
    refute Group.is_member?(group, third_user)

    {:ok, group} = Group.remove_member(group, other_user)
    refute Group.is_member?(group, other_user)
  end
end
