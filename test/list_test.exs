defmodule Pleroma.ListTest do
  alias Pleroma.{User, Repo}
  use Pleroma.DataCase

  import Pleroma.Factory
  import Ecto.Query

  test "creating a list" do
    user = insert(:user)
    {:ok, %Pleroma.List{} = list} = Pleroma.List.create("title", user)
    %Pleroma.List{title: title} = Pleroma.List.get(list.id, user)
    assert title == "title"
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
    {:ok, %{following: following}} = Pleroma.List.follow(list, other_user)
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
end
