defmodule Pleroma.Web.ActivityPub.ActivityPubTest do
  use Pleroma.DataCase
  alias Pleroma.Web.ActivityPub.ActivityPub
  alias Pleroma.{Activity, Object}
  alias Pleroma.Builders.ActivityBuilder

  describe "insertion" do
    test "inserts a given map into the activity database, giving it an id if it has none." do
      data = %{
        "ok" => true
      }

      {:ok, %Activity{} = activity} = ActivityPub.insert(data)
      assert activity.data["ok"] == data["ok"]
      assert is_binary(activity.data["id"])

      given_id = "bla"
      data = %{
        "ok" => true,
        "id" => given_id
      }

      {:ok, %Activity{} = activity} = ActivityPub.insert(data)
      assert activity.data["ok"] == data["ok"]
      assert activity.data["id"] == given_id
    end

    test "adds an id to a given object if it lacks one" do
      data = %{
        "object" => %{
          "ok" => true
        }
      }

      {:ok, %Activity{} = activity} = ActivityPub.insert(data)
      assert is_binary(activity.data["object"]["id"])
    end
  end

  describe "fetch activities for recipients" do
    test "retrieve the activities for certain recipients" do
      {:ok, activity_one} = ActivityBuilder.insert(%{"to" => ["someone"]})
      {:ok, activity_two} = ActivityBuilder.insert(%{"to" => ["someone_else"]})
      {:ok, _activity_three} = ActivityBuilder.insert(%{"to" => ["noone"]})

      activities = ActivityPub.fetch_activities(["someone", "someone_else"])
      assert length(activities) == 2
      assert activities == [activity_one, activity_two]
    end
  end

  describe "fetch activities in context" do
    test "retrieves activities that have a given context" do
      {:ok, activity} = ActivityBuilder.insert(%{"context" => "2hu"})
      {:ok, activity_two} = ActivityBuilder.insert(%{"context" => "2hu"})
      {:ok, _activity_three} = ActivityBuilder.insert(%{"context" => "3hu"})

      activities = ActivityPub.fetch_activities_for_context("2hu")

      assert activities == [activity, activity_two]
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

    test "retrieves ids starting from a since_id" do
      activities = ActivityBuilder.insert_list(30)
      later_activities = ActivityBuilder.insert_list(10)
      since_id = List.last(activities).id
      last_expected = List.last(later_activities)

      activities = ActivityPub.fetch_public_activities(%{"since_id" => since_id})
      last = List.last(activities)

      assert length(activities) == 10
      assert last == last_expected
    end
  end

  describe "uploading files" do
    test "copies the file to the configured folder" do
      file = %Plug.Upload{content_type: "image/jpg", path: Path.absname("test/fixtures/image.jpg"), filename: "an_image.jpg"}

      {:ok, %Object{} = object} = ActivityPub.upload(file)
      assert object.data["name"] == "an_image.jpg"
    end
  end
end
