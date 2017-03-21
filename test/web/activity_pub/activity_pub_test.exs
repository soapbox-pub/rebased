defmodule Pleroma.Web.ActivityPub.ActivityPubTest do
  use Pleroma.DataCase
  alias Pleroma.Web.ActivityPub.ActivityPub
  alias Pleroma.Activity
  alias Pleroma.Builders.{UserBuilder, ActivityBuilder}

  describe "insertion" do
    test "inserts a given map into the activity database" do
      data = %{
        ok: true
      }

      {:ok, %Activity{} = activity} = ActivityPub.insert(data)
      assert activity.data == data
    end
  end

  describe "fetch activities" do
    test "retrieves all public activities" do
      %{user: user, public: public} = ActivityBuilder.public_and_non_public

      activities = ActivityPub.fetch_public_activities
      assert length(activities) == 1
      assert Enum.at(activities, 0) == public
    end
  end
end
