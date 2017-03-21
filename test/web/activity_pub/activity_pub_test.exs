defmodule Pleroma.Web.ActivityPub.ActivityPubTest do
  use Pleroma.DataCase
  alias Pleroma.Web.ActivityPub.ActivityPub
  alias Pleroma.Activity
  alias Pleroma.Builders.ActivityBuilder

  describe "insertion" do
    test "inserts a given map into the activity database" do
      data = %{
        ok: true
      }

      {:ok, %Activity{} = activity} = ActivityPub.insert(data)
      assert activity.data == data
    end
  end

  describe "public fetch activities" do
    test "retrieves public activities" do
      %{public: public} = ActivityBuilder.public_and_non_public

      activities = ActivityPub.fetch_public_activities
      assert length(activities) == 1
      assert Enum.at(activities, 0) == public
    end

    test "retrieves a maximum of 20 activities" do
      activities = ActivityBuilder.insert_list(30)
      last_expected = List.last(activities)

      activities = ActivityPub.fetch_public_activities
      last = List.last(activities)

      assert length(activities) == 20
      assert last == last_expected
    end
  end
end
