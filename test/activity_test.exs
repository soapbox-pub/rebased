# Pleroma: A lightweight social networking server
# Copyright © 2017-2018 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.ActivityTest do
  use Pleroma.DataCase
  alias Pleroma.Activity
  alias Pleroma.Bookmark
  alias Pleroma.Object
  import Pleroma.Factory

  test "returns an activity by it's AP id" do
    activity = insert(:note_activity)
    found_activity = Activity.get_by_ap_id(activity.data["id"])

    assert activity == found_activity
  end

  test "returns activities by it's objects AP ids" do
    activity = insert(:note_activity)
    [found_activity] = Activity.get_all_create_by_object_ap_id(activity.data["object"]["id"])

    assert activity == found_activity
  end

  test "returns the activity that created an object" do
    activity = insert(:note_activity)

    found_activity = Activity.get_create_by_object_ap_id(activity.data["object"]["id"])

    assert activity == found_activity
  end

  test "preloading object preloads bookmarks" do
    user1 = insert(:user)
    user2 = insert(:user)
    activity = insert(:note_activity)
    {:ok, bookmark1} = Bookmark.create(user1.id, activity.id)
    {:ok, bookmark2} = Bookmark.create(user2.id, activity.id)
    bookmarks = Enum.sort([bookmark1, bookmark2])

    queried_activity =
      Ecto.Query.from(a in Activity, where: a.id == ^activity.id)
      |> Activity.with_preloaded_object()
      |> Repo.one()

    assert Enum.sort(queried_activity.bookmarks) == bookmarks

    queried_activity = Activity.get_by_ap_id_with_object(activity.data["id"])
    assert Enum.sort(queried_activity.bookmarks) == bookmarks

    queried_activity = Activity.get_by_id_with_object(activity.id)
    assert Enum.sort(queried_activity.bookmarks) == bookmarks

    queried_activity =
      Activity.get_create_by_object_ap_id_with_object(Object.normalize(activity).data["id"])

    assert Enum.sort(queried_activity.bookmarks) == bookmarks
  end
end
