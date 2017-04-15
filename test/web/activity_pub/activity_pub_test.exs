defmodule Pleroma.Web.ActivityPub.ActivityPubTest do
  use Pleroma.DataCase
  alias Pleroma.Web.ActivityPub.ActivityPub
  alias Pleroma.{Activity, Object, User}
  alias Pleroma.Builders.ActivityBuilder

  import Pleroma.Factory

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

    test "adds an id to a given object if it lacks one and inserts it to the object database" do
      data = %{
        "object" => %{
          "ok" => true
        }
      }

      {:ok, %Activity{} = activity} = ActivityPub.insert(data)
      assert is_binary(activity.data["object"]["id"])
      assert %Object{} = Object.get_by_ap_id(activity.data["object"]["id"])
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

    test "retrieves ids up to max_id" do
      _first_activities = ActivityBuilder.insert_list(10)
      activities = ActivityBuilder.insert_list(20)
      later_activities = ActivityBuilder.insert_list(10)
      max_id = List.first(later_activities).id
      last_expected = List.last(activities)

      activities = ActivityPub.fetch_public_activities(%{"max_id" => max_id})
      last = List.last(activities)

      assert length(activities) == 20
      assert last == last_expected
    end
  end

  describe "like an object" do
    test "adds a like activity to the db" do
      note_activity = insert(:note_activity)
      object = Object.get_by_ap_id(note_activity.data["object"]["id"])
      user = insert(:user)
      user_two = insert(:user)

      {:ok, like_activity, object} = ActivityPub.like(user, object)

      assert like_activity.data["actor"] == user.ap_id
      assert like_activity.data["type"] == "Like"
      assert like_activity.data["object"] == object.data["id"]
      assert like_activity.data["to"] == [User.ap_followers(user)]
      assert object.data["like_count"] == 1
      assert object.data["likes"] == [user.ap_id]

      # Just return the original activity if the user already liked it.
      {:ok, same_like_activity, object} = ActivityPub.like(user, object)

      assert like_activity == same_like_activity
      assert object.data["likes"] == [user.ap_id]

      [note_activity] = Activity.all_by_object_ap_id(object.data["id"])
      assert note_activity.data["object"]["like_count"] == 1

      {:ok, _like_activity, object} = ActivityPub.like(user_two, object)
      assert object.data["like_count"] == 2
    end
  end

  describe "unliking" do
    test "unliking a previously liked object" do
      note_activity = insert(:note_activity)
      object = Object.get_by_ap_id(note_activity.data["object"]["id"])
      user = insert(:user)

      # Unliking something that hasn't been liked does nothing
      {:ok, object} = ActivityPub.unlike(user, object)
      assert object.data["like_count"] == 0

      {:ok, like_activity, object} = ActivityPub.like(user, object)
      assert object.data["like_count"] == 1

      {:ok, object} = ActivityPub.unlike(user, object)
      assert object.data["like_count"] == 0

      assert Repo.get(Activity, like_activity.id) == nil
    end
  end

  describe "announcing an object" do
    test "adds an announce activity to the db" do
      note_activity = insert(:note_activity)
      object = Object.get_by_ap_id(note_activity.data["object"]["id"])
      user = insert(:user)

      {:ok, announce_activity, object} = ActivityPub.announce(user, object)
      assert object.data["announcement_count"] == 1
      assert object.data["announcements"] == [user.ap_id]
      assert announce_activity.data["to"] == [User.ap_followers(user)]
      assert announce_activity.data["object"] == object.data["id"]
      assert announce_activity.data["actor"] == user.ap_id
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
