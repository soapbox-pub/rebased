defmodule Pleroma.Web.ActivityPub.ActivityPubTest do
  use Pleroma.DataCase
  alias Pleroma.Web.ActivityPub.ActivityPub
  alias Pleroma.Web.ActivityPub.Utils
  alias Pleroma.Web.CommonAPI
  alias Pleroma.{Activity, Object, User}
  alias Pleroma.Builders.ActivityBuilder

  import Pleroma.Factory

  describe "building a user from his ap id" do
    test "it returns a user" do
      user_id = "http://mastodon.example.org/users/admin"
      {:ok, user} = ActivityPub.make_user_from_ap_id(user_id)
      assert user.ap_id == user_id
      assert user.nickname == "admin@mastodon.example.org"
      assert user.info["source_data"]
      assert user.info["ap_enabled"]
      assert user.follower_address == "http://mastodon.example.org/users/admin/followers"
    end
  end

  describe "insertion" do
    test "returns the activity if one with the same id is already in" do
      activity = insert(:note_activity)
      {:ok, new_activity} = ActivityPub.insert(activity.data)

      assert activity == new_activity
    end

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
        "id" => given_id,
        "context" => "blabla"
      }

      {:ok, %Activity{} = activity} = ActivityPub.insert(data)
      assert activity.data["ok"] == data["ok"]
      assert activity.data["id"] == given_id
      assert activity.data["context"] == "blabla"
      assert activity.data["context_id"]
    end

    test "adds a context when none is there" do
      data = %{
        "id" => "some_id",
        "object" => %{
          "id" => "object_id"
        }
      }

      {:ok, %Activity{} = activity} = ActivityPub.insert(data)

      assert is_binary(activity.data["context"])
      assert is_binary(activity.data["object"]["context"])
      assert activity.data["context_id"]
      assert activity.data["object"]["context_id"]
    end

    test "adds an id to a given object if it lacks one and is a note and inserts it to the object database" do
      data = %{
        "object" => %{
          "type" => "Note",
          "ok" => true
        }
      }

      {:ok, %Activity{} = activity} = ActivityPub.insert(data)
      assert is_binary(activity.data["object"]["id"])
      assert %Object{} = Object.get_by_ap_id(activity.data["object"]["id"])
    end
  end

  describe "create activities" do
    test "removes doubled 'to' recipients" do
      user = insert(:user)

      {:ok, activity} =
        ActivityPub.create(%{
          to: ["user1", "user1", "user2"],
          actor: user,
          context: "",
          object: %{}
        })

      assert activity.data["to"] == ["user1", "user2"]
      assert activity.actor == user.ap_id
      assert activity.recipients == ["user1", "user2"]
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
      {:ok, activity} = ActivityBuilder.insert(%{"type" => "Create", "context" => "2hu"})
      {:ok, activity_two} = ActivityBuilder.insert(%{"type" => "Create", "context" => "2hu"})
      {:ok, _activity_three} = ActivityBuilder.insert(%{"type" => "Create", "context" => "3hu"})
      {:ok, _activity_four} = ActivityBuilder.insert(%{"type" => "Announce", "context" => "2hu"})
      activity_five = insert(:note_activity)
      user = insert(:user)

      {:ok, user} = User.block(user, %{ap_id: activity_five.data["actor"]})

      activities = ActivityPub.fetch_activities_for_context("2hu", %{"blocking_user" => user})
      assert activities == [activity_two, activity]
    end
  end

  test "doesn't return blocked activities" do
    activity_one = insert(:note_activity)
    activity_two = insert(:note_activity)
    activity_three = insert(:note_activity)
    user = insert(:user)
    booster = insert(:user)
    {:ok, user} = User.block(user, %{ap_id: activity_one.data["actor"]})

    activities = ActivityPub.fetch_activities([], %{"blocking_user" => user})

    assert Enum.member?(activities, activity_two)
    assert Enum.member?(activities, activity_three)
    refute Enum.member?(activities, activity_one)

    {:ok, user} = User.unblock(user, %{ap_id: activity_one.data["actor"]})

    activities = ActivityPub.fetch_activities([], %{"blocking_user" => user})

    assert Enum.member?(activities, activity_two)
    assert Enum.member?(activities, activity_three)
    assert Enum.member?(activities, activity_one)

    {:ok, user} = User.block(user, %{ap_id: activity_three.data["actor"]})
    {:ok, _announce, %{data: %{"id" => id}}} = CommonAPI.repeat(activity_three.id, booster)
    %Activity{} = boost_activity = Activity.get_create_activity_by_object_ap_id(id)
    activity_three = Repo.get(Activity, activity_three.id)

    activities = ActivityPub.fetch_activities([], %{"blocking_user" => user})

    assert Enum.member?(activities, activity_two)
    refute Enum.member?(activities, activity_three)
    refute Enum.member?(activities, boost_activity)
    assert Enum.member?(activities, activity_one)

    activities = ActivityPub.fetch_activities([], %{"blocking_user" => nil})

    assert Enum.member?(activities, activity_two)
    assert Enum.member?(activities, activity_three)
    assert Enum.member?(activities, boost_activity)
    assert Enum.member?(activities, activity_one)
  end

  describe "public fetch activities" do
    test "doesn't retrieve unlisted activities" do
      user = insert(:user)

      {:ok, unlisted_activity} =
        CommonAPI.post(user, %{"status" => "yeah", "visibility" => "unlisted"})

      {:ok, listed_activity} = CommonAPI.post(user, %{"status" => "yeah"})

      [activity] = ActivityPub.fetch_public_activities()

      assert activity == listed_activity
    end

    test "retrieves public activities" do
      _activities = ActivityPub.fetch_public_activities()

      %{public: public} = ActivityBuilder.public_and_non_public()

      activities = ActivityPub.fetch_public_activities()
      assert length(activities) == 1
      assert Enum.at(activities, 0) == public
    end

    test "retrieves a maximum of 20 activities" do
      activities = ActivityBuilder.insert_list(30)
      last_expected = List.last(activities)

      activities = ActivityPub.fetch_public_activities()
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
      assert like_activity.data["to"] == [User.ap_followers(user), note_activity.data["actor"]]
      assert like_activity.data["context"] == object.data["context"]
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

      {:ok, _, _, object} = ActivityPub.unlike(user, object)
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

      assert announce_activity.data["to"] == [
               User.ap_followers(user),
               note_activity.data["actor"]
             ]

      assert announce_activity.data["object"] == object.data["id"]
      assert announce_activity.data["actor"] == user.ap_id
      assert announce_activity.data["context"] == object.data["context"]
    end
  end

  describe "unannouncing an object" do
    test "unannouncing a previously announced object" do
      note_activity = insert(:note_activity)
      object = Object.get_by_ap_id(note_activity.data["object"]["id"])
      user = insert(:user)

      # Unannouncing an object that is not announced does nothing
      # {:ok, object} = ActivityPub.unannounce(user, object)
      # assert object.data["announcement_count"] == 0

      {:ok, announce_activity, object} = ActivityPub.announce(user, object)
      assert object.data["announcement_count"] == 1

      {:ok, unannounce_activity, object} = ActivityPub.unannounce(user, object)
      assert object.data["announcement_count"] == 0

      assert unannounce_activity.data["to"] == [
               User.ap_followers(user),
               announce_activity.data["actor"]
             ]

      assert unannounce_activity.data["type"] == "Undo"
      assert unannounce_activity.data["object"] == announce_activity.data
      assert unannounce_activity.data["actor"] == user.ap_id
      assert unannounce_activity.data["context"] == announce_activity.data["context"]

      assert Repo.get(Activity, announce_activity.id) == nil
    end
  end

  describe "uploading files" do
    test "copies the file to the configured folder" do
      file = %Plug.Upload{
        content_type: "image/jpg",
        path: Path.absname("test/fixtures/image.jpg"),
        filename: "an_image.jpg"
      }

      {:ok, %Object{} = object} = ActivityPub.upload(file)
      assert object.data["name"] == "an_image.jpg"
    end

    test "works with base64 encoded images" do
      file = %{
        "img" => data_uri()
      }

      {:ok, %Object{}} = ActivityPub.upload(file)
    end
  end

  describe "fetch the latest Follow" do
    test "fetches the latest Follow activity" do
      %Activity{data: %{"type" => "Follow"}} = activity = insert(:follow_activity)
      follower = Repo.get_by(User, ap_id: activity.data["actor"])
      followed = Repo.get_by(User, ap_id: activity.data["object"])

      assert activity == Utils.fetch_latest_follow(follower, followed)
    end
  end

  describe "fetching an object" do
    test "it fetches an object" do
      {:ok, object} =
        ActivityPub.fetch_object_from_id("http://mastodon.example.org/@admin/99541947525187367")

      assert activity = Activity.get_create_activity_by_object_ap_id(object.data["id"])
      assert activity.data["id"]

      {:ok, object_again} =
        ActivityPub.fetch_object_from_id("http://mastodon.example.org/@admin/99541947525187367")

      assert [attachment] = object.data["attachment"]
      assert is_list(attachment["url"])

      assert object == object_again
    end

    test "it works with objects only available via Ostatus" do
      {:ok, object} = ActivityPub.fetch_object_from_id("https://shitposter.club/notice/2827873")
      assert activity = Activity.get_create_activity_by_object_ap_id(object.data["id"])
      assert activity.data["id"]

      {:ok, object_again} =
        ActivityPub.fetch_object_from_id("https://shitposter.club/notice/2827873")

      assert object == object_again
    end

    test "it correctly stitches up conversations between ostatus and ap" do
      last = "https://mstdn.io/users/mayuutann/statuses/99568293732299394"
      {:ok, object} = ActivityPub.fetch_object_from_id(last)

      object = Object.get_by_ap_id(object.data["inReplyTo"])
      assert object
    end
  end

  describe "following / unfollowing" do
    test "creates a follow activity" do
      follower = insert(:user)
      followed = insert(:user)

      {:ok, activity} = ActivityPub.follow(follower, followed)
      assert activity.data["type"] == "Follow"
      assert activity.data["actor"] == follower.ap_id
      assert activity.data["object"] == followed.ap_id
    end

    test "creates an undo activity for the last follow" do
      follower = insert(:user)
      followed = insert(:user)

      {:ok, follow_activity} = ActivityPub.follow(follower, followed)
      {:ok, activity} = ActivityPub.unfollow(follower, followed)

      assert activity.data["type"] == "Undo"
      assert activity.data["actor"] == follower.ap_id

      assert is_map(activity.data["object"])
      assert activity.data["object"]["type"] == "Follow"
      assert activity.data["object"]["object"] == followed.ap_id
      assert activity.data["object"]["id"] == follow_activity.data["id"]
    end
  end

  describe "blocking / unblocking" do
    test "creates a block activity" do
      blocker = insert(:user)
      blocked = insert(:user)

      {:ok, activity} = ActivityPub.block(blocker, blocked)

      assert activity.data["type"] == "Block"
      assert activity.data["actor"] == blocker.ap_id
      assert activity.data["object"] == blocked.ap_id
    end

    test "creates an undo activity for the last block" do
      blocker = insert(:user)
      blocked = insert(:user)

      {:ok, block_activity} = ActivityPub.block(blocker, blocked)
      {:ok, activity} = ActivityPub.unblock(blocker, blocked)

      assert activity.data["type"] == "Undo"
      assert activity.data["actor"] == blocker.ap_id

      assert is_map(activity.data["object"])
      assert activity.data["object"]["type"] == "Block"
      assert activity.data["object"]["object"] == blocked.ap_id
      assert activity.data["object"]["id"] == block_activity.data["id"]
    end
  end

  describe "deletion" do
    test "it creates a delete activity and deletes the original object" do
      note = insert(:note_activity)
      object = Object.get_by_ap_id(note.data["object"]["id"])
      {:ok, delete} = ActivityPub.delete(object)

      assert delete.data["type"] == "Delete"
      assert delete.data["actor"] == note.data["actor"]
      assert delete.data["object"] == note.data["object"]["id"]

      assert Repo.get(Activity, delete.id) != nil

      assert Repo.get(Object, object.id) == nil
    end
  end

  describe "timeline post-processing" do
    test "it filters broken threads" do
      user1 = insert(:user)
      user2 = insert(:user)
      user3 = insert(:user)

      {:ok, user1} = User.follow(user1, user3)
      assert User.following?(user1, user3)

      {:ok, user2} = User.follow(user2, user3)
      assert User.following?(user2, user3)

      {:ok, user3} = User.follow(user3, user2)
      assert User.following?(user3, user2)

      {:ok, public_activity} = CommonAPI.post(user3, %{"status" => "hi 1"})

      {:ok, private_activity_1} = CommonAPI.post(user3, %{"status" => "hi 2", "visibility" => "private"})
      {:ok, private_activity_2} = CommonAPI.post(user2, %{"status" => "hi 3", "visibility" => "private", "in_reply_to_status_id" => private_activity_1.id})
      {:ok, private_activity_3} = CommonAPI.post(user3, %{"status" => "hi 4", "visibility" => "private", "in_reply_to_status_id" => private_activity_2.id})

      assert user1.following == [user3.ap_id <> "/followers", user1.ap_id]

      activities =
        ActivityPub.fetch_activities([user1.ap_id | user1.following])

      assert [public_activity, private_activity_1, private_activity_3] == activities
      assert length(activities) == 3

      activities = ActivityPub.contain_timeline(activities, user1)

      assert [public_activity, private_activity_1] == activities
      assert length(activities) == 2
    end
  end

  test "it can fetch plume articles" do
    {:ok, object} =
      ActivityPub.fetch_object_from_id(
        "https://baptiste.gelez.xyz/~/PlumeDevelopment/this-month-in-plume-june-2018/"
      )

    assert object
  end

  describe "update" do
    test "it creates an update activity with the new user data" do
      user = insert(:user)
      {:ok, user} = Pleroma.Web.WebFinger.ensure_keys_present(user)
      user_data = Pleroma.Web.ActivityPub.UserView.render("user.json", %{user: user})

      {:ok, update} =
        ActivityPub.update(%{
          actor: user_data["id"],
          to: [user.follower_address],
          cc: [],
          object: user_data
        })

      assert update.data["actor"] == user.ap_id
      assert update.data["to"] == [user.follower_address]
      assert update.data["object"]["id"] == user_data["id"]
      assert update.data["object"]["type"] == user_data["type"]
    end
  end

  test "it can fetch peertube videos" do
    {:ok, object} =
      ActivityPub.fetch_object_from_id(
        "https://peertube.moe/videos/watch/df5f464b-be8d-46fb-ad81-2d4c2d1630e3"
      )

    assert object
  end

  def data_uri do
    File.read!("test/fixtures/avatar_data_uri")
  end
end
