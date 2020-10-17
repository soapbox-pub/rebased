# Pleroma: A lightweight social networking server
# Copyright © 2017-2020 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.ListTest do
  alias Pleroma.Repo
  use Pleroma.DataCase

  import Pleroma.Factory

  test "creating a list" do
    user = insert(:user)
    {:ok, %Pleroma.List{} = list} = Pleroma.List.create("title", user)
    %Pleroma.List{title: title} = Pleroma.List.get(list.id, user)
    assert title == "title"
  end

  test "validates title" do
    user = insert(:user)

    assert {:error, changeset} = Pleroma.List.create("", user)
    assert changeset.errors == [title: {"can't be blank", [validation: :required]}]
  end

  test "getting a list not belonging to the user" do
    user = insert(:user)
    other_user = insert(:user)
    {:ok, %Pleroma.List{} = list} = Pleroma.List.create("title", user)
    ret = Pleroma.List.get(list.id, other_user)
    assert is_nil(ret)
  end

  test "adding an user to a list" do
    user = insert(:user)
    other_user = insert(:user)
    {:ok, list} = Pleroma.List.create("title", user)
    {:ok, %{following: following}} = Pleroma.List.follow(list, other_user)
    assert [other_user.follower_address] == following
  end

  test "removing an user from a list" do
    user = insert(:user)
    other_user = insert(:user)
    {:ok, list} = Pleroma.List.create("title", user)
    {:ok, %{following: _following}} = Pleroma.List.follow(list, other_user)
    {:ok, %{following: following}} = Pleroma.List.unfollow(list, other_user)
    assert [] == following
  end

  test "renaming a list" do
    user = insert(:user)
    {:ok, list} = Pleroma.List.create("title", user)
    {:ok, %{title: title}} = Pleroma.List.rename(list, "new")
    assert "new" == title
  end

  test "deleting a list" do
    user = insert(:user)
    {:ok, list} = Pleroma.List.create("title", user)
    {:ok, list} = Pleroma.List.delete(list)
    assert is_nil(Repo.get(Pleroma.List, list.id))
  end

  test "getting users in a list" do
    user = insert(:user)
    other_user = insert(:user)
    third_user = insert(:user)
    {:ok, list} = Pleroma.List.create("title", user)
    {:ok, list} = Pleroma.List.follow(list, other_user)
    {:ok, list} = Pleroma.List.follow(list, third_user)
    {:ok, following} = Pleroma.List.get_following(list)
    assert other_user in following
    assert third_user in following
  end

  test "getting all lists by an user" do
    user = insert(:user)
    other_user = insert(:user)
    {:ok, list_one} = Pleroma.List.create("title", user)
    {:ok, list_two} = Pleroma.List.create("other title", user)
    {:ok, list_three} = Pleroma.List.create("third title", other_user)
    lists = Pleroma.List.for_user(user, %{})
    assert list_one in lists
    assert list_two in lists
    refute list_three in lists
  end

  test "getting all lists the user is a member of" do
    user = insert(:user)
    other_user = insert(:user)
    {:ok, list_one} = Pleroma.List.create("title", user)
    {:ok, list_two} = Pleroma.List.create("other title", user)
    {:ok, list_three} = Pleroma.List.create("third title", other_user)
    {:ok, list_one} = Pleroma.List.follow(list_one, other_user)
    {:ok, list_two} = Pleroma.List.follow(list_two, other_user)
    {:ok, list_three} = Pleroma.List.follow(list_three, user)

    lists = Pleroma.List.get_lists_from_activity(%Pleroma.Activity{actor: other_user.ap_id})
    assert list_one in lists
    assert list_two in lists
    refute list_three in lists
  end

  test "getting own lists a given user belongs to" do
    owner = insert(:user)
    not_owner = insert(:user)
    member_1 = insert(:user)
    member_2 = insert(:user)
    {:ok, owned_list} = Pleroma.List.create("owned", owner)
    {:ok, not_owned_list} = Pleroma.List.create("not owned", not_owner)
    {:ok, owned_list} = Pleroma.List.follow(owned_list, member_1)
    {:ok, owned_list} = Pleroma.List.follow(owned_list, member_2)
    {:ok, not_owned_list} = Pleroma.List.follow(not_owned_list, member_1)
    {:ok, not_owned_list} = Pleroma.List.follow(not_owned_list, member_2)

    lists_1 = Pleroma.List.get_lists_account_belongs(owner, member_1)
    assert owned_list in lists_1
    refute not_owned_list in lists_1
    lists_2 = Pleroma.List.get_lists_account_belongs(owner, member_2)
    assert owned_list in lists_2
    refute not_owned_list in lists_2
  end

  test "get by ap_id" do
    user = insert(:user)
    {:ok, list} = Pleroma.List.create("foo", user)
    assert Pleroma.List.get_by_ap_id(list.ap_id) == list
  end

  test "memberships" do
    user = insert(:user)
    member = insert(:user)
    {:ok, list} = Pleroma.List.create("foo", user)
    {:ok, list} = Pleroma.List.follow(list, member)

    assert Pleroma.List.memberships(member) == [list.ap_id]
  end

  test "member?" do
    user = insert(:user)
    member = insert(:user)

    {:ok, list} = Pleroma.List.create("foo", user)
    {:ok, list} = Pleroma.List.follow(list, member)

    assert Pleroma.List.member?(list, member)
    refute Pleroma.List.member?(list, user)
  end
end
