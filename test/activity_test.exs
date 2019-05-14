# Pleroma: A lightweight social networking server
# Copyright © 2017-2018 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.ActivityTest do
  use Pleroma.DataCase
  alias Pleroma.Activity
  alias Pleroma.Bookmark
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

  test "preloading a bookmark" do
    user = insert(:user)
    user2 = insert(:user)
    user3 = insert(:user)
    activity = insert(:note_activity)
    {:ok, _bookmark} = Bookmark.create(user.id, activity.id)
    {:ok, _bookmark2} = Bookmark.create(user2.id, activity.id)
    {:ok, bookmark3} = Bookmark.create(user3.id, activity.id)

    queried_activity =
      Ecto.Query.from(Pleroma.Activity)
      |> Activity.with_preloaded_bookmark(user3)
      |> Repo.one()

    assert queried_activity.bookmark == bookmark3
  end

  describe "getting a bookmark" do
    test "when association is loaded" do
      user = insert(:user)
      activity = insert(:note_activity)
      {:ok, bookmark} = Bookmark.create(user.id, activity.id)

      queried_activity =
        Ecto.Query.from(Pleroma.Activity)
        |> Activity.with_preloaded_bookmark(user)
        |> Repo.one()

      assert Activity.get_bookmark(queried_activity, user) == bookmark
    end

    test "when association is not loaded" do
      user = insert(:user)
      activity = insert(:note_activity)
      {:ok, bookmark} = Bookmark.create(user.id, activity.id)

      queried_activity =
        Ecto.Query.from(Pleroma.Activity)
        |> Repo.one()

      assert Activity.get_bookmark(queried_activity, user) == bookmark
    end
  end
end
