# Pleroma: A lightweight social networking server
# Copyright © 2017-2018 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.ActivityTest do
  use Pleroma.DataCase
  alias Pleroma.Activity
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

  test "reply count" do
    %{id: id, data: %{"object" => %{"id" => object_ap_id}}} = activity = insert(:note_activity)

    replies_count = activity.data["object"]["repliesCount"] || 0
    expected_increase = replies_count + 1
    Activity.increase_replies_count(object_ap_id)
    %{data: %{"object" => %{"repliesCount" => actual_increase}}} = Activity.get_by_id(id)
    assert expected_increase == actual_increase
    expected_decrease = expected_increase - 1
    Activity.decrease_replies_count(object_ap_id)
    %{data: %{"object" => %{"repliesCount" => actual_decrease}}} = Activity.get_by_id(id)
    assert expected_decrease == actual_decrease
  end
end
