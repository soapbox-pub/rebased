# Pleroma: A lightweight social networking server
# Copyright © 2017-2021 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.GroupTest do
  use Pleroma.DataCase, async: true

  alias Pleroma.Group
  alias Pleroma.Repo

  import Pleroma.Factory

  test "get_for_object/1 gets a group based on the group object or the create activity" do
    user = insert(:user)

    {:ok, group} =
      Group.create(%{owner_id: user.id, slug: "cofe", name: "Cofe", description: "corndog"})

    group = Repo.preload(group, :user)

    group_object = %{
      "id" => group.user.ap_id,
      "type" => "Group"
    }

    assert group.id == Group.get_for_object(group_object).id

    # Same works if wrapped in a 'create'
    group_create = %{
      "type" => "Create",
      "object" => group_object
    }

    assert group.id == Group.get_for_object(group_create).id

    # Nil for nonsense

    assert nil == Group.get_for_object(%{"nothing" => "PS4 games"})
  end

  test "get_object_group/1 gets the group an object is directed to" do
    user = insert(:user)
    {:ok, group} = Group.create(%{owner_id: user.id, slug: "cofe"})
    group = Repo.preload(group, :user)
    message = insert(:note, data: %{"to" => [group.user.ap_id]})

    assert group.id == Group.get_object_group(message).id
  end

  test "a user can create a group" do
    user = insert(:user)

    {:ok, group} =
      Group.create(%{owner_id: user.id, slug: "cofe", name: "Cofe", description: "corndog"})

    group = Repo.preload(group, :user)

    assert group.user.actor_type == "Group"
    assert group.user.nickname == "cofe"
    assert group.owner_id == user.id
    assert group.name == "Cofe"
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

    {:ok, group} =
      Group.create(%{owner_id: user.id, slug: "cofe", name: "Cofe", description: "corndog"})

    assert [] == Group.members(group)

    {:ok, group} = Group.add_member(group, other_user)
    assert [other_user] == Group.members(group)

    assert Group.is_member?(group, other_user)
    refute Group.is_member?(group, third_user)

    {:ok, group} = Group.remove_member(group, other_user)
    refute Group.is_member?(group, other_user)
  end

  test "get_by_user/1 returns a group if the user is a Group actor" do
    group = insert(:group)
    assert Group.get_by_user(group.user).id == group.id
  end
end
