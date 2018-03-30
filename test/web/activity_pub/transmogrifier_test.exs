defmodule Pleroma.Web.ActivityPub.TransmogrifierTest do
  use Pleroma.DataCase
  alias Pleroma.Web.ActivityPub.Transmogrifier
  alias Pleroma.Web.OStatus
  alias Pleroma.Activity
  alias Pleroma.User
  alias Pleroma.Repo
  alias Pleroma.Web.Websub.WebsubClientSubscription
  alias Pleroma.Web.Websub.WebsubServerSubscription
  import Ecto.Query

  import Pleroma.Factory
  alias Pleroma.Web.CommonAPI

  describe "handle_incoming" do
    test "it ignores an incoming notice if we already have it" do
      activity = insert(:note_activity)

      data =
        File.read!("test/fixtures/mastodon-post-activity.json")
        |> Poison.decode!()
        |> Map.put("object", activity.data["object"])

      {:ok, returned_activity} = Transmogrifier.handle_incoming(data)

      assert activity == returned_activity
    end

    test "it fetches replied-to activities if we don't have them" do
      data =
        File.read!("test/fixtures/mastodon-post-activity.json")
        |> Poison.decode!()

      object =
        data["object"]
        |> Map.put("inReplyTo", "https://shitposter.club/notice/2827873")

      data =
        data
        |> Map.put("object", object)

      {:ok, returned_activity} = Transmogrifier.handle_incoming(data)

      assert activity =
               Activity.get_create_activity_by_object_ap_id(
                 "tag:shitposter.club,2017-05-05:noticeId=2827873:objectType=comment"
               )

      assert returned_activity.data["object"]["inReplyToAtomUri"] ==
               "https://shitposter.club/notice/2827873"

      assert returned_activity.data["object"]["inReplyToStatusId"] == activity.id
    end

    test "it works for incoming notices" do
      data = File.read!("test/fixtures/mastodon-post-activity.json") |> Poison.decode!()

      {:ok, %Activity{data: data, local: false}} = Transmogrifier.handle_incoming(data)

      assert data["id"] ==
               "http://mastodon.example.org/users/admin/statuses/99512778738411822/activity"

      assert data["context"] ==
               "tag:mastodon.example.org,2018-02-12:objectId=20:objectType=Conversation"

      assert data["to"] == ["https://www.w3.org/ns/activitystreams#Public"]

      assert data["cc"] == [
               "http://mastodon.example.org/users/admin/followers",
               "http://localtesting.pleroma.lol/users/lain"
             ]

      assert data["actor"] == "http://mastodon.example.org/users/admin"

      object = data["object"]
      assert object["id"] == "http://mastodon.example.org/users/admin/statuses/99512778738411822"

      assert object["to"] == ["https://www.w3.org/ns/activitystreams#Public"]

      assert object["cc"] == [
               "http://mastodon.example.org/users/admin/followers",
               "http://localtesting.pleroma.lol/users/lain"
             ]

      assert object["actor"] == "http://mastodon.example.org/users/admin"
      assert object["attributedTo"] == "http://mastodon.example.org/users/admin"

      assert object["context"] ==
               "tag:mastodon.example.org,2018-02-12:objectId=20:objectType=Conversation"

      assert object["sensitive"] == true
    end

    test "it works for incoming notices with hashtags" do
      data = File.read!("test/fixtures/mastodon-post-activity-hashtag.json") |> Poison.decode!()

      {:ok, %Activity{data: data, local: false}} = Transmogrifier.handle_incoming(data)
      assert Enum.at(data["object"]["tag"], 2) == "moo"
    end

    test "it works for incoming follow requests" do
      user = insert(:user)

      data =
        File.read!("test/fixtures/mastodon-follow-activity.json") |> Poison.decode!()
        |> Map.put("object", user.ap_id)

      {:ok, %Activity{data: data, local: false}} = Transmogrifier.handle_incoming(data)

      assert data["actor"] == "http://mastodon.example.org/users/admin"
      assert data["type"] == "Follow"
      assert data["id"] == "http://mastodon.example.org/users/admin#follows/2"
      assert User.following?(User.get_by_ap_id(data["actor"]), user)
    end

    test "it works for incoming likes" do
      user = insert(:user)
      {:ok, activity} = CommonAPI.post(user, %{"status" => "hello"})

      data =
        File.read!("test/fixtures/mastodon-like.json") |> Poison.decode!()
        |> Map.put("object", activity.data["object"]["id"])

      {:ok, %Activity{data: data, local: false}} = Transmogrifier.handle_incoming(data)

      assert data["actor"] == "http://mastodon.example.org/users/admin"
      assert data["type"] == "Like"
      assert data["id"] == "http://mastodon.example.org/users/admin#likes/2"
      assert data["object"] == activity.data["object"]["id"]
    end

    test "it works for incoming announces" do
      data = File.read!("test/fixtures/mastodon-announce.json") |> Poison.decode!()

      {:ok, %Activity{data: data, local: false}} = Transmogrifier.handle_incoming(data)

      assert data["actor"] == "http://mastodon.example.org/users/admin"
      assert data["type"] == "Announce"

      assert data["id"] ==
               "http://mastodon.example.org/users/admin/statuses/99542391527669785/activity"

      assert data["object"] ==
               "http://mastodon.example.org/users/admin/statuses/99541947525187367"

      assert Activity.get_create_activity_by_object_ap_id(data["object"])
    end

    test "it works for incoming announces with an existing activity" do
      user = insert(:user)
      {:ok, activity} = CommonAPI.post(user, %{"status" => "hey"})

      data =
        File.read!("test/fixtures/mastodon-announce.json")
        |> Poison.decode!()
        |> Map.put("object", activity.data["object"]["id"])

      {:ok, %Activity{data: data, local: false}} = Transmogrifier.handle_incoming(data)

      assert data["actor"] == "http://mastodon.example.org/users/admin"
      assert data["type"] == "Announce"

      assert data["id"] ==
               "http://mastodon.example.org/users/admin/statuses/99542391527669785/activity"

      assert data["object"] == activity.data["object"]["id"]

      assert Activity.get_create_activity_by_object_ap_id(data["object"]).id == activity.id
    end

    test "it works for incoming update activities" do
      data = File.read!("test/fixtures/mastodon-post-activity.json") |> Poison.decode!()

      {:ok, %Activity{data: data, local: false}} = Transmogrifier.handle_incoming(data)
      update_data = File.read!("test/fixtures/mastodon-update.json") |> Poison.decode!()

      object =
        update_data["object"]
        |> Map.put("actor", data["actor"])
        |> Map.put("id", data["actor"])

      update_data =
        update_data
        |> Map.put("actor", data["actor"])
        |> Map.put("object", object)

      {:ok, %Activity{data: data, local: false}} = Transmogrifier.handle_incoming(update_data)

      user = User.get_cached_by_ap_id(data["actor"])
      assert user.name == "gargle"

      assert user.avatar["url"] == [
               %{
                 "href" =>
                   "https://cd.niu.moe/accounts/avatars/000/033/323/original/fd7f8ae0b3ffedc9.jpeg"
               }
             ]

      assert user.info["banner"]["url"] == [
               %{
                 "href" =>
                   "https://cd.niu.moe/accounts/headers/000/033/323/original/850b3448fa5fd477.png"
               }
             ]

      assert user.bio == "<p>Some bio</p>"
    end

    test "it works for incoming deletes" do
      activity = insert(:note_activity)

      data =
        File.read!("test/fixtures/mastodon-delete.json")
        |> Poison.decode!()

      object =
        data["object"]
        |> Map.put("id", activity.data["object"]["id"])

      data =
        data
        |> Map.put("object", object)
        |> Map.put("actor", activity.data["actor"])

      {:ok, %Activity{data: data, local: false}} = Transmogrifier.handle_incoming(data)

      refute Repo.get(Activity, activity.id)
    end
  end

  describe "prepare outgoing" do
    test "it turns mentions into tags" do
      user = insert(:user)
      other_user = insert(:user)

      {:ok, activity} =
        CommonAPI.post(user, %{"status" => "hey, @#{other_user.nickname}, how are ya? #2hu"})

      {:ok, modified} = Transmogrifier.prepare_outgoing(activity.data)
      object = modified["object"]

      expected_mention = %{
        "href" => other_user.ap_id,
        "name" => "@#{other_user.nickname}",
        "type" => "Mention"
      }

      expected_tag = %{
        "href" => Pleroma.Web.Endpoint.url() <> "/tags/2hu",
        "type" => "Hashtag",
        "name" => "#2hu"
      }

      assert Enum.member?(object["tag"], expected_tag)
      assert Enum.member?(object["tag"], expected_mention)
    end

    test "it adds the sensitive property" do
      user = insert(:user)

      {:ok, activity} = CommonAPI.post(user, %{"status" => "#nsfw hey"})
      {:ok, modified} = Transmogrifier.prepare_outgoing(activity.data)

      assert modified["object"]["sensitive"]
    end

    test "it adds the json-ld context and the conversation property" do
      user = insert(:user)

      {:ok, activity} = CommonAPI.post(user, %{"status" => "hey"})
      {:ok, modified} = Transmogrifier.prepare_outgoing(activity.data)

      assert modified["@context"] == "https://www.w3.org/ns/activitystreams"
      assert modified["object"]["conversation"] == modified["context"]
    end

    test "it sets the 'attributedTo' property to the actor of the object if it doesn't have one" do
      user = insert(:user)

      {:ok, activity} = CommonAPI.post(user, %{"status" => "hey"})
      {:ok, modified} = Transmogrifier.prepare_outgoing(activity.data)

      assert modified["object"]["actor"] == modified["object"]["attributedTo"]
    end

    test "it translates ostatus IDs to external URLs" do
      incoming = File.read!("test/fixtures/incoming_note_activity.xml")
      {:ok, [referent_activity]} = OStatus.handle_incoming(incoming)

      user = insert(:user)

      {:ok, activity, _} = CommonAPI.favorite(referent_activity.id, user)
      {:ok, modified} = Transmogrifier.prepare_outgoing(activity.data)

      assert modified["object"] == "http://gs.example.org:4040/index.php/notice/29"
    end

    test "it translates ostatus reply_to IDs to external URLs" do
      incoming = File.read!("test/fixtures/incoming_note_activity.xml")
      {:ok, [referred_activity]} = OStatus.handle_incoming(incoming)

      user = insert(:user)

      {:ok, activity} =
        CommonAPI.post(user, %{"status" => "HI!", "in_reply_to_status_id" => referred_activity.id})

      {:ok, modified} = Transmogrifier.prepare_outgoing(activity.data)

      assert modified["object"]["inReplyTo"] == "http://gs.example.org:4040/index.php/notice/29"
    end
  end

  describe "user upgrade" do
    test "it upgrades a user to activitypub" do
      user =
        insert(:user, %{
          nickname: "rye@niu.moe",
          local: false,
          ap_id: "https://niu.moe/users/rye",
          follower_address: User.ap_followers(%User{nickname: "rye@niu.moe"})
        })

      user_two = insert(:user, %{following: [user.follower_address]})

      {:ok, activity} = CommonAPI.post(user, %{"status" => "test"})
      {:ok, unrelated_activity} = CommonAPI.post(user_two, %{"status" => "test"})
      assert "http://localhost:4001/users/rye@niu.moe/followers" in activity.recipients

      user = Repo.get(User, user.id)
      assert user.info["note_count"] == 1

      {:ok, user} = Transmogrifier.upgrade_user_from_ap_id("https://niu.moe/users/rye")
      assert user.info["ap_enabled"]
      assert user.info["note_count"] == 1
      assert user.follower_address == "https://niu.moe/users/rye/followers"

      # Wait for the background task
      :timer.sleep(1000)

      user = Repo.get(User, user.id)
      assert user.info["note_count"] == 1

      activity = Repo.get(Activity, activity.id)
      assert user.follower_address in activity.recipients

      assert %{
               "url" => [
                 %{
                   "href" =>
                     "https://cdn.niu.moe/accounts/avatars/000/033/323/original/fd7f8ae0b3ffedc9.jpeg"
                 }
               ]
             } = user.avatar

      assert %{
               "url" => [
                 %{
                   "href" =>
                     "https://cdn.niu.moe/accounts/headers/000/033/323/original/850b3448fa5fd477.png"
                 }
               ]
             } = user.info["banner"]

      refute "..." in activity.recipients

      unrelated_activity = Repo.get(Activity, unrelated_activity.id)
      refute user.follower_address in unrelated_activity.recipients

      user_two = Repo.get(User, user_two.id)
      assert user.follower_address in user_two.following
      refute "..." in user_two.following
    end
  end

  describe "maybe_retire_websub" do
    test "it deletes all websub client subscripitions with the user as topic" do
      subscription = %WebsubClientSubscription{topic: "https://niu.moe/users/rye.atom"}
      {:ok, ws} = Repo.insert(subscription)

      subscription = %WebsubClientSubscription{topic: "https://niu.moe/users/pasty.atom"}
      {:ok, ws2} = Repo.insert(subscription)

      Transmogrifier.maybe_retire_websub("https://niu.moe/users/rye")

      refute Repo.get(WebsubClientSubscription, ws.id)
      assert Repo.get(WebsubClientSubscription, ws2.id)
    end
  end
end
