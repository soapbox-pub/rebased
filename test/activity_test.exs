defmodule Pleroma.ActivityTest do
  use Pleroma.DataCase
  alias Pleroma.Activity
  import Pleroma.Factory

  test "returns an activity by it's AP id" do
    activity = insert(:note_activity)
    found_activity = Pleroma.Activity.get_by_ap_id(activity.data["id"])

    assert activity == found_activity
  end

  test "returns activities by it's objects AP ids" do
    activity = insert(:note_activity)
    [found_activity] = Pleroma.Activity.all_by_object_ap_id(activity.data["object"]["id"])

    assert activity == found_activity
  end

  test "returns the activity that created an object" do
    activity = insert(:note_activity)

    found_activity =
      Pleroma.Activity.get_create_activity_by_object_ap_id(activity.data["object"]["id"])

    assert activity == found_activity
  end

  test "returns tombstone" do
    activity = insert(:note_activity)
    deleted = DateTime.utc_now()

    assert Pleroma.Activity.get_tombstone(activity, deleted) == %{
             id: activity.data["object"]["id"],
             context: activity.data["context"],
             type: "tombstone",
             published: activity.data["published"],
             deleted: deleted
           }
  end

  test "swaps data with tombstone" do
    activity = insert(:note_activity)

    {:ok, deleted} = Pleroma.Activity.swap_data_with_tombstone(activity)
    assert deleted.data.type == "tombstone"

    found_activity = Repo.get(Activity, activity.id)

    assert deleted.data.type == found_activity.data["type"]
  end
end
