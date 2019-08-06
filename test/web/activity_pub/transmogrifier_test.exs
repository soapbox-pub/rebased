# Pleroma: A lightweight social networking server
# Copyright © 2017-2018 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.ActivityPub.TransmogrifierTest do
  use Pleroma.DataCase
  alias Pleroma.Activity
  alias Pleroma.Object
  alias Pleroma.Object.Fetcher
  alias Pleroma.Repo
  alias Pleroma.User
  alias Pleroma.Web.ActivityPub.ActivityPub
  alias Pleroma.Web.ActivityPub.Transmogrifier
  alias Pleroma.Web.CommonAPI
  alias Pleroma.Web.OStatus
  alias Pleroma.Web.Websub.WebsubClientSubscription

  import Mock
  import Pleroma.Factory
  import ExUnit.CaptureLog

  setup_all do
    Tesla.Mock.mock_global(fn env -> apply(HttpRequestMock, :request, [env]) end)
    :ok
  end

  describe "handle_incoming" do
    test "it ignores an incoming notice if we already have it" do
      activity = insert(:note_activity)

      data =
        File.read!("test/fixtures/mastodon-post-activity.json")
        |> Poison.decode!()
        |> Map.put("object", Object.normalize(activity).data)

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

      data = Map.put(data, "object", object)
      {:ok, returned_activity} = Transmogrifier.handle_incoming(data)
      returned_object = Object.normalize(returned_activity, false)

      assert activity =
               Activity.get_create_by_object_ap_id(
                 "tag:shitposter.club,2017-05-05:noticeId=2827873:objectType=comment"
               )

      assert returned_object.data["inReplyToAtomUri"] == "https://shitposter.club/notice/2827873"
    end

    test "it does not fetch replied-to activities beyond max_replies_depth" do
      data =
        File.read!("test/fixtures/mastodon-post-activity.json")
        |> Poison.decode!()

      object =
        data["object"]
        |> Map.put("inReplyTo", "https://shitposter.club/notice/2827873")

      data = Map.put(data, "object", object)

      with_mock Pleroma.Web.Federator,
        allowed_incoming_reply_depth?: fn _ -> false end do
        {:ok, returned_activity} = Transmogrifier.handle_incoming(data)

        returned_object = Object.normalize(returned_activity, false)

        refute Activity.get_create_by_object_ap_id(
                 "tag:shitposter.club,2017-05-05:noticeId=2827873:objectType=comment"
               )

        assert returned_object.data["inReplyToAtomUri"] ==
                 "https://shitposter.club/notice/2827873"
      end
    end

    test "it does not crash if the object in inReplyTo can't be fetched" do
      data =
        File.read!("test/fixtures/mastodon-post-activity.json")
        |> Poison.decode!()

      object =
        data["object"]
        |> Map.put("inReplyTo", "https://404.site/whatever")

      data =
        data
        |> Map.put("object", object)

      assert capture_log(fn ->
               {:ok, _returned_activity} = Transmogrifier.handle_incoming(data)
             end) =~ "[error] Couldn't fetch \"\"https://404.site/whatever\"\", error: nil"
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

      object_data = Object.normalize(data["object"]).data

      assert object_data["id"] ==
               "http://mastodon.example.org/users/admin/statuses/99512778738411822"

      assert object_data["to"] == ["https://www.w3.org/ns/activitystreams#Public"]

      assert object_data["cc"] == [
               "http://mastodon.example.org/users/admin/followers",
               "http://localtesting.pleroma.lol/users/lain"
             ]

      assert object_data["actor"] == "http://mastodon.example.org/users/admin"
      assert object_data["attributedTo"] == "http://mastodon.example.org/users/admin"

      assert object_data["context"] ==
               "tag:mastodon.example.org,2018-02-12:objectId=20:objectType=Conversation"

      assert object_data["sensitive"] == true

      user = User.get_cached_by_ap_id(object_data["actor"])

      assert user.info.note_count == 1
    end

    test "it works for incoming notices with hashtags" do
      data = File.read!("test/fixtures/mastodon-post-activity-hashtag.json") |> Poison.decode!()

      {:ok, %Activity{data: data, local: false}} = Transmogrifier.handle_incoming(data)
      object = Object.normalize(data["object"])

      assert Enum.at(object.data["tag"], 2) == "moo"
    end

    test "it works for incoming questions" do
      data = File.read!("test/fixtures/mastodon-question-activity.json") |> Poison.decode!()

      {:ok, %Activity{local: false} = activity} = Transmogrifier.handle_incoming(data)

      object = Object.normalize(activity)

      assert Enum.all?(object.data["oneOf"], fn choice ->
               choice["name"] in [
                 "Dunno",
                 "Everyone knows that!",
                 "25 char limit is dumb",
                 "I can't even fit a funny"
               ]
             end)
    end

    test "it rewrites Note votes to Answers and increments vote counters on question activities" do
      user = insert(:user)

      {:ok, activity} =
        CommonAPI.post(user, %{
          "status" => "suya...",
          "poll" => %{"options" => ["suya", "suya.", "suya.."], "expires_in" => 10}
        })

      object = Object.normalize(activity)

      data =
        File.read!("test/fixtures/mastodon-vote.json")
        |> Poison.decode!()
        |> Kernel.put_in(["to"], user.ap_id)
        |> Kernel.put_in(["object", "inReplyTo"], object.data["id"])
        |> Kernel.put_in(["object", "to"], user.ap_id)

      {:ok, %Activity{local: false} = activity} = Transmogrifier.handle_incoming(data)
      answer_object = Object.normalize(activity)
      assert answer_object.data["type"] == "Answer"
      object = Object.get_by_ap_id(object.data["id"])

      assert Enum.any?(
               object.data["oneOf"],
               fn
                 %{"name" => "suya..", "replies" => %{"totalItems" => 1}} -> true
                 _ -> false
               end
             )
    end

    test "it works for incoming notices with contentMap" do
      data =
        File.read!("test/fixtures/mastodon-post-activity-contentmap.json") |> Poison.decode!()

      {:ok, %Activity{data: data, local: false}} = Transmogrifier.handle_incoming(data)
      object = Object.normalize(data["object"])

      assert object.data["content"] ==
               "<p><span class=\"h-card\"><a href=\"http://localtesting.pleroma.lol/users/lain\" class=\"u-url mention\">@<span>lain</span></a></span></p>"
    end

    test "it works for incoming notices with to/cc not being an array (kroeg)" do
      data = File.read!("test/fixtures/kroeg-post-activity.json") |> Poison.decode!()

      {:ok, %Activity{data: data, local: false}} = Transmogrifier.handle_incoming(data)
      object = Object.normalize(data["object"])

      assert object.data["content"] ==
               "<p>henlo from my Psion netBook</p><p>message sent from my Psion netBook</p>"
    end

    test "it works for incoming announces with actor being inlined (kroeg)" do
      data = File.read!("test/fixtures/kroeg-announce-with-inline-actor.json") |> Poison.decode!()

      {:ok, %Activity{data: data, local: false}} = Transmogrifier.handle_incoming(data)

      assert data["actor"] == "https://puckipedia.com/"
    end

    test "it works for incoming notices with tag not being an array (kroeg)" do
      data = File.read!("test/fixtures/kroeg-array-less-emoji.json") |> Poison.decode!()

      {:ok, %Activity{data: data, local: false}} = Transmogrifier.handle_incoming(data)
      object = Object.normalize(data["object"])

      assert object.data["emoji"] == %{
               "icon_e_smile" => "https://puckipedia.com/forum/images/smilies/icon_e_smile.png"
             }

      data = File.read!("test/fixtures/kroeg-array-less-hashtag.json") |> Poison.decode!()

      {:ok, %Activity{data: data, local: false}} = Transmogrifier.handle_incoming(data)
      object = Object.normalize(data["object"])

      assert "test" in object.data["tag"]
    end

    test "it works for incoming notices with url not being a string (prismo)" do
      data = File.read!("test/fixtures/prismo-url-map.json") |> Poison.decode!()

      {:ok, %Activity{data: data, local: false}} = Transmogrifier.handle_incoming(data)
      object = Object.normalize(data["object"])

      assert object.data["url"] == "https://prismo.news/posts/83"
    end

    test "it cleans up incoming notices which are not really DMs" do
      user = insert(:user)
      other_user = insert(:user)

      to = [user.ap_id, other_user.ap_id]

      data =
        File.read!("test/fixtures/mastodon-post-activity.json")
        |> Poison.decode!()
        |> Map.put("to", to)
        |> Map.put("cc", [])

      object =
        data["object"]
        |> Map.put("to", to)
        |> Map.put("cc", [])

      data = Map.put(data, "object", object)

      {:ok, %Activity{data: data, local: false} = activity} = Transmogrifier.handle_incoming(data)

      assert data["to"] == []
      assert data["cc"] == to

      object_data = Object.normalize(activity).data

      assert object_data["to"] == []
      assert object_data["cc"] == to
    end

    test "it works for incoming likes" do
      user = insert(:user)
      {:ok, activity} = CommonAPI.post(user, %{"status" => "hello"})

      data =
        File.read!("test/fixtures/mastodon-like.json")
        |> Poison.decode!()
        |> Map.put("object", activity.data["object"])

      {:ok, %Activity{data: data, local: false}} = Transmogrifier.handle_incoming(data)

      assert data["actor"] == "http://mastodon.example.org/users/admin"
      assert data["type"] == "Like"
      assert data["id"] == "http://mastodon.example.org/users/admin#likes/2"
      assert data["object"] == activity.data["object"]
    end

    test "it returns an error for incoming unlikes wihout a like activity" do
      user = insert(:user)
      {:ok, activity} = CommonAPI.post(user, %{"status" => "leave a like pls"})

      data =
        File.read!("test/fixtures/mastodon-undo-like.json")
        |> Poison.decode!()
        |> Map.put("object", activity.data["object"])

      assert Transmogrifier.handle_incoming(data) == :error
    end

    test "it works for incoming unlikes with an existing like activity" do
      user = insert(:user)
      {:ok, activity} = CommonAPI.post(user, %{"status" => "leave a like pls"})

      like_data =
        File.read!("test/fixtures/mastodon-like.json")
        |> Poison.decode!()
        |> Map.put("object", activity.data["object"])

      {:ok, %Activity{data: like_data, local: false}} = Transmogrifier.handle_incoming(like_data)

      data =
        File.read!("test/fixtures/mastodon-undo-like.json")
        |> Poison.decode!()
        |> Map.put("object", like_data)
        |> Map.put("actor", like_data["actor"])

      {:ok, %Activity{data: data, local: false}} = Transmogrifier.handle_incoming(data)

      assert data["actor"] == "http://mastodon.example.org/users/admin"
      assert data["type"] == "Undo"
      assert data["id"] == "http://mastodon.example.org/users/admin#likes/2/undo"
      assert data["object"]["id"] == "http://mastodon.example.org/users/admin#likes/2"
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

      assert Activity.get_create_by_object_ap_id(data["object"])
    end

    test "it works for incoming announces with an existing activity" do
      user = insert(:user)
      {:ok, activity} = CommonAPI.post(user, %{"status" => "hey"})

      data =
        File.read!("test/fixtures/mastodon-announce.json")
        |> Poison.decode!()
        |> Map.put("object", activity.data["object"])

      {:ok, %Activity{data: data, local: false}} = Transmogrifier.handle_incoming(data)

      assert data["actor"] == "http://mastodon.example.org/users/admin"
      assert data["type"] == "Announce"

      assert data["id"] ==
               "http://mastodon.example.org/users/admin/statuses/99542391527669785/activity"

      assert data["object"] == activity.data["object"]

      assert Activity.get_create_by_object_ap_id(data["object"]).id == activity.id
    end

    test "it does not clobber the addressing on announce activities" do
      user = insert(:user)
      {:ok, activity} = CommonAPI.post(user, %{"status" => "hey"})

      data =
        File.read!("test/fixtures/mastodon-announce.json")
        |> Poison.decode!()
        |> Map.put("object", Object.normalize(activity).data["id"])
        |> Map.put("to", ["http://mastodon.example.org/users/admin/followers"])
        |> Map.put("cc", [])

      {:ok, %Activity{data: data, local: false}} = Transmogrifier.handle_incoming(data)

      assert data["to"] == ["http://mastodon.example.org/users/admin/followers"]
    end

    test "it ensures that as:Public activities make it to their followers collection" do
      user = insert(:user)

      data =
        File.read!("test/fixtures/mastodon-post-activity.json")
        |> Poison.decode!()
        |> Map.put("actor", user.ap_id)
        |> Map.put("to", ["https://www.w3.org/ns/activitystreams#Public"])
        |> Map.put("cc", [])

      object =
        data["object"]
        |> Map.put("attributedTo", user.ap_id)
        |> Map.put("to", ["https://www.w3.org/ns/activitystreams#Public"])
        |> Map.put("cc", [])
        |> Map.put("id", user.ap_id <> "/activities/12345678")

      data = Map.put(data, "object", object)

      {:ok, %Activity{data: data, local: false}} = Transmogrifier.handle_incoming(data)

      assert data["cc"] == [User.ap_followers(user)]
    end

    test "it ensures that address fields become lists" do
      user = insert(:user)

      data =
        File.read!("test/fixtures/mastodon-post-activity.json")
        |> Poison.decode!()
        |> Map.put("actor", user.ap_id)
        |> Map.put("to", nil)
        |> Map.put("cc", nil)

      object =
        data["object"]
        |> Map.put("attributedTo", user.ap_id)
        |> Map.put("to", nil)
        |> Map.put("cc", nil)
        |> Map.put("id", user.ap_id <> "/activities/12345678")

      data = Map.put(data, "object", object)

      {:ok, %Activity{data: data, local: false}} = Transmogrifier.handle_incoming(data)

      assert !is_nil(data["to"])
      assert !is_nil(data["cc"])
    end

    test "it strips internal likes" do
      data =
        File.read!("test/fixtures/mastodon-post-activity.json")
        |> Poison.decode!()

      likes = %{
        "first" =>
          "http://mastodon.example.org/objects/dbdbc507-52c8-490d-9b7c-1e1d52e5c132/likes?page=1",
        "id" => "http://mastodon.example.org/objects/dbdbc507-52c8-490d-9b7c-1e1d52e5c132/likes",
        "totalItems" => 3,
        "type" => "OrderedCollection"
      }

      object = Map.put(data["object"], "likes", likes)
      data = Map.put(data, "object", object)

      {:ok, %Activity{object: object}} = Transmogrifier.handle_incoming(data)

      refute Map.has_key?(object.data, "likes")
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

      assert user.info.banner["url"] == [
               %{
                 "href" =>
                   "https://cd.niu.moe/accounts/headers/000/033/323/original/850b3448fa5fd477.png"
               }
             ]

      assert user.bio == "<p>Some bio</p>"
    end

    test "it works with custom profile fields" do
      {:ok, activity} =
        "test/fixtures/mastodon-post-activity.json"
        |> File.read!()
        |> Poison.decode!()
        |> Transmogrifier.handle_incoming()

      user = User.get_cached_by_ap_id(activity.actor)

      assert User.Info.fields(user.info) == [
               %{"name" => "foo", "value" => "bar"},
               %{"name" => "foo1", "value" => "bar1"}
             ]

      update_data = File.read!("test/fixtures/mastodon-update.json") |> Poison.decode!()

      object =
        update_data["object"]
        |> Map.put("actor", user.ap_id)
        |> Map.put("id", user.ap_id)

      update_data =
        update_data
        |> Map.put("actor", user.ap_id)
        |> Map.put("object", object)

      {:ok, _update_activity} = Transmogrifier.handle_incoming(update_data)

      user = User.get_cached_by_ap_id(user.ap_id)

      assert User.Info.fields(user.info) == [
               %{"name" => "foo", "value" => "updated"},
               %{"name" => "foo1", "value" => "updated"}
             ]
    end

    test "it works for incoming update activities which lock the account" do
      data = File.read!("test/fixtures/mastodon-post-activity.json") |> Poison.decode!()

      {:ok, %Activity{data: data, local: false}} = Transmogrifier.handle_incoming(data)
      update_data = File.read!("test/fixtures/mastodon-update.json") |> Poison.decode!()

      object =
        update_data["object"]
        |> Map.put("actor", data["actor"])
        |> Map.put("id", data["actor"])
        |> Map.put("manuallyApprovesFollowers", true)

      update_data =
        update_data
        |> Map.put("actor", data["actor"])
        |> Map.put("object", object)

      {:ok, %Activity{data: data, local: false}} = Transmogrifier.handle_incoming(update_data)

      user = User.get_cached_by_ap_id(data["actor"])
      assert user.info.locked == true
    end

    test "it works for incoming deletes" do
      activity = insert(:note_activity)

      data =
        File.read!("test/fixtures/mastodon-delete.json")
        |> Poison.decode!()

      object =
        data["object"]
        |> Map.put("id", activity.data["object"])

      data =
        data
        |> Map.put("object", object)
        |> Map.put("actor", activity.data["actor"])

      {:ok, %Activity{local: false}} = Transmogrifier.handle_incoming(data)

      refute Activity.get_by_id(activity.id)
    end

    test "it fails for incoming deletes with spoofed origin" do
      activity = insert(:note_activity)

      data =
        File.read!("test/fixtures/mastodon-delete.json")
        |> Poison.decode!()

      object =
        data["object"]
        |> Map.put("id", activity.data["object"])

      data =
        data
        |> Map.put("object", object)

      assert capture_log(fn ->
               :error = Transmogrifier.handle_incoming(data)
             end) =~
               "[error] Could not decode user at fetch http://mastodon.example.org/users/gargron, {:error, {:error, :nxdomain}}"

      assert Activity.get_by_id(activity.id)
    end

    test "it works for incoming user deletes" do
      %{ap_id: ap_id} = insert(:user, ap_id: "http://mastodon.example.org/users/admin")

      data =
        File.read!("test/fixtures/mastodon-delete-user.json")
        |> Poison.decode!()

      {:ok, _} = Transmogrifier.handle_incoming(data)

      refute User.get_cached_by_ap_id(ap_id)
    end

    test "it fails for incoming user deletes with spoofed origin" do
      %{ap_id: ap_id} = insert(:user)

      data =
        File.read!("test/fixtures/mastodon-delete-user.json")
        |> Poison.decode!()
        |> Map.put("actor", ap_id)

      assert :error == Transmogrifier.handle_incoming(data)
      assert User.get_cached_by_ap_id(ap_id)
    end

    test "it works for incoming unannounces with an existing notice" do
      user = insert(:user)
      {:ok, activity} = CommonAPI.post(user, %{"status" => "hey"})

      announce_data =
        File.read!("test/fixtures/mastodon-announce.json")
        |> Poison.decode!()
        |> Map.put("object", activity.data["object"])

      {:ok, %Activity{data: announce_data, local: false}} =
        Transmogrifier.handle_incoming(announce_data)

      data =
        File.read!("test/fixtures/mastodon-undo-announce.json")
        |> Poison.decode!()
        |> Map.put("object", announce_data)
        |> Map.put("actor", announce_data["actor"])

      {:ok, %Activity{data: data, local: false}} = Transmogrifier.handle_incoming(data)

      assert data["type"] == "Undo"
      assert object_data = data["object"]
      assert object_data["type"] == "Announce"
      assert object_data["object"] == activity.data["object"]

      assert object_data["id"] ==
               "http://mastodon.example.org/users/admin/statuses/99542391527669785/activity"
    end

    test "it works for incomming unfollows with an existing follow" do
      user = insert(:user)

      follow_data =
        File.read!("test/fixtures/mastodon-follow-activity.json")
        |> Poison.decode!()
        |> Map.put("object", user.ap_id)

      {:ok, %Activity{data: _, local: false}} = Transmogrifier.handle_incoming(follow_data)

      data =
        File.read!("test/fixtures/mastodon-unfollow-activity.json")
        |> Poison.decode!()
        |> Map.put("object", follow_data)

      {:ok, %Activity{data: data, local: false}} = Transmogrifier.handle_incoming(data)

      assert data["type"] == "Undo"
      assert data["object"]["type"] == "Follow"
      assert data["object"]["object"] == user.ap_id
      assert data["actor"] == "http://mastodon.example.org/users/admin"

      refute User.following?(User.get_cached_by_ap_id(data["actor"]), user)
    end

    test "it works for incoming blocks" do
      user = insert(:user)

      data =
        File.read!("test/fixtures/mastodon-block-activity.json")
        |> Poison.decode!()
        |> Map.put("object", user.ap_id)

      {:ok, %Activity{data: data, local: false}} = Transmogrifier.handle_incoming(data)

      assert data["type"] == "Block"
      assert data["object"] == user.ap_id
      assert data["actor"] == "http://mastodon.example.org/users/admin"

      blocker = User.get_cached_by_ap_id(data["actor"])

      assert User.blocks?(blocker, user)
    end

    test "incoming blocks successfully tear down any follow relationship" do
      blocker = insert(:user)
      blocked = insert(:user)

      data =
        File.read!("test/fixtures/mastodon-block-activity.json")
        |> Poison.decode!()
        |> Map.put("object", blocked.ap_id)
        |> Map.put("actor", blocker.ap_id)

      {:ok, blocker} = User.follow(blocker, blocked)
      {:ok, blocked} = User.follow(blocked, blocker)

      assert User.following?(blocker, blocked)
      assert User.following?(blocked, blocker)

      {:ok, %Activity{data: data, local: false}} = Transmogrifier.handle_incoming(data)

      assert data["type"] == "Block"
      assert data["object"] == blocked.ap_id
      assert data["actor"] == blocker.ap_id

      blocker = User.get_cached_by_ap_id(data["actor"])
      blocked = User.get_cached_by_ap_id(data["object"])

      assert User.blocks?(blocker, blocked)

      refute User.following?(blocker, blocked)
      refute User.following?(blocked, blocker)
    end

    test "it works for incoming unblocks with an existing block" do
      user = insert(:user)

      block_data =
        File.read!("test/fixtures/mastodon-block-activity.json")
        |> Poison.decode!()
        |> Map.put("object", user.ap_id)

      {:ok, %Activity{data: _, local: false}} = Transmogrifier.handle_incoming(block_data)

      data =
        File.read!("test/fixtures/mastodon-unblock-activity.json")
        |> Poison.decode!()
        |> Map.put("object", block_data)

      {:ok, %Activity{data: data, local: false}} = Transmogrifier.handle_incoming(data)
      assert data["type"] == "Undo"
      assert data["object"]["type"] == "Block"
      assert data["object"]["object"] == user.ap_id
      assert data["actor"] == "http://mastodon.example.org/users/admin"

      blocker = User.get_cached_by_ap_id(data["actor"])

      refute User.blocks?(blocker, user)
    end

    test "it works for incoming accepts which were pre-accepted" do
      follower = insert(:user)
      followed = insert(:user)

      {:ok, follower} = User.follow(follower, followed)
      assert User.following?(follower, followed) == true

      {:ok, follow_activity} = ActivityPub.follow(follower, followed)

      accept_data =
        File.read!("test/fixtures/mastodon-accept-activity.json")
        |> Poison.decode!()
        |> Map.put("actor", followed.ap_id)

      object =
        accept_data["object"]
        |> Map.put("actor", follower.ap_id)
        |> Map.put("id", follow_activity.data["id"])

      accept_data = Map.put(accept_data, "object", object)

      {:ok, activity} = Transmogrifier.handle_incoming(accept_data)
      refute activity.local

      assert activity.data["object"] == follow_activity.data["id"]

      follower = User.get_cached_by_id(follower.id)

      assert User.following?(follower, followed) == true
    end

    test "it works for incoming accepts which were orphaned" do
      follower = insert(:user)
      followed = insert(:user, %{info: %User.Info{locked: true}})

      {:ok, follow_activity} = ActivityPub.follow(follower, followed)

      accept_data =
        File.read!("test/fixtures/mastodon-accept-activity.json")
        |> Poison.decode!()
        |> Map.put("actor", followed.ap_id)

      accept_data =
        Map.put(accept_data, "object", Map.put(accept_data["object"], "actor", follower.ap_id))

      {:ok, activity} = Transmogrifier.handle_incoming(accept_data)
      assert activity.data["object"] == follow_activity.data["id"]

      follower = User.get_cached_by_id(follower.id)

      assert User.following?(follower, followed) == true
    end

    test "it works for incoming accepts which are referenced by IRI only" do
      follower = insert(:user)
      followed = insert(:user, %{info: %User.Info{locked: true}})

      {:ok, follow_activity} = ActivityPub.follow(follower, followed)

      accept_data =
        File.read!("test/fixtures/mastodon-accept-activity.json")
        |> Poison.decode!()
        |> Map.put("actor", followed.ap_id)
        |> Map.put("object", follow_activity.data["id"])

      {:ok, activity} = Transmogrifier.handle_incoming(accept_data)
      assert activity.data["object"] == follow_activity.data["id"]

      follower = User.get_cached_by_id(follower.id)

      assert User.following?(follower, followed) == true
    end

    test "it fails for incoming accepts which cannot be correlated" do
      follower = insert(:user)
      followed = insert(:user, %{info: %User.Info{locked: true}})

      accept_data =
        File.read!("test/fixtures/mastodon-accept-activity.json")
        |> Poison.decode!()
        |> Map.put("actor", followed.ap_id)

      accept_data =
        Map.put(accept_data, "object", Map.put(accept_data["object"], "actor", follower.ap_id))

      :error = Transmogrifier.handle_incoming(accept_data)

      follower = User.get_cached_by_id(follower.id)

      refute User.following?(follower, followed) == true
    end

    test "it fails for incoming rejects which cannot be correlated" do
      follower = insert(:user)
      followed = insert(:user, %{info: %User.Info{locked: true}})

      accept_data =
        File.read!("test/fixtures/mastodon-reject-activity.json")
        |> Poison.decode!()
        |> Map.put("actor", followed.ap_id)

      accept_data =
        Map.put(accept_data, "object", Map.put(accept_data["object"], "actor", follower.ap_id))

      :error = Transmogrifier.handle_incoming(accept_data)

      follower = User.get_cached_by_id(follower.id)

      refute User.following?(follower, followed) == true
    end

    test "it works for incoming rejects which are orphaned" do
      follower = insert(:user)
      followed = insert(:user, %{info: %User.Info{locked: true}})

      {:ok, follower} = User.follow(follower, followed)
      {:ok, _follow_activity} = ActivityPub.follow(follower, followed)

      assert User.following?(follower, followed) == true

      reject_data =
        File.read!("test/fixtures/mastodon-reject-activity.json")
        |> Poison.decode!()
        |> Map.put("actor", followed.ap_id)

      reject_data =
        Map.put(reject_data, "object", Map.put(reject_data["object"], "actor", follower.ap_id))

      {:ok, activity} = Transmogrifier.handle_incoming(reject_data)
      refute activity.local

      follower = User.get_cached_by_id(follower.id)

      assert User.following?(follower, followed) == false
    end

    test "it works for incoming rejects which are referenced by IRI only" do
      follower = insert(:user)
      followed = insert(:user, %{info: %User.Info{locked: true}})

      {:ok, follower} = User.follow(follower, followed)
      {:ok, follow_activity} = ActivityPub.follow(follower, followed)

      assert User.following?(follower, followed) == true

      reject_data =
        File.read!("test/fixtures/mastodon-reject-activity.json")
        |> Poison.decode!()
        |> Map.put("actor", followed.ap_id)
        |> Map.put("object", follow_activity.data["id"])

      {:ok, %Activity{data: _}} = Transmogrifier.handle_incoming(reject_data)

      follower = User.get_cached_by_id(follower.id)

      assert User.following?(follower, followed) == false
    end

    test "it rejects activities without a valid ID" do
      user = insert(:user)

      data =
        File.read!("test/fixtures/mastodon-follow-activity.json")
        |> Poison.decode!()
        |> Map.put("object", user.ap_id)
        |> Map.put("id", "")

      :error = Transmogrifier.handle_incoming(data)
    end

    test "it remaps video URLs as attachments if necessary" do
      {:ok, object} =
        Fetcher.fetch_object_from_id(
          "https://peertube.moe/videos/watch/df5f464b-be8d-46fb-ad81-2d4c2d1630e3"
        )

      attachment = %{
        "type" => "Link",
        "mediaType" => "video/mp4",
        "href" =>
          "https://peertube.moe/static/webseed/df5f464b-be8d-46fb-ad81-2d4c2d1630e3-480.mp4",
        "mimeType" => "video/mp4",
        "size" => 5_015_880,
        "url" => [
          %{
            "href" =>
              "https://peertube.moe/static/webseed/df5f464b-be8d-46fb-ad81-2d4c2d1630e3-480.mp4",
            "mediaType" => "video/mp4",
            "type" => "Link"
          }
        ],
        "width" => 480
      }

      assert object.data["url"] ==
               "https://peertube.moe/videos/watch/df5f464b-be8d-46fb-ad81-2d4c2d1630e3"

      assert object.data["attachment"] == [attachment]
    end

    test "it accepts Flag activities" do
      user = insert(:user)
      other_user = insert(:user)

      {:ok, activity} = CommonAPI.post(user, %{"status" => "test post"})
      object = Object.normalize(activity)

      message = %{
        "@context" => "https://www.w3.org/ns/activitystreams",
        "cc" => [user.ap_id],
        "object" => [user.ap_id, object.data["id"]],
        "type" => "Flag",
        "content" => "blocked AND reported!!!",
        "actor" => other_user.ap_id
      }

      assert {:ok, activity} = Transmogrifier.handle_incoming(message)

      assert activity.data["object"] == [user.ap_id, object.data["id"]]
      assert activity.data["content"] == "blocked AND reported!!!"
      assert activity.data["actor"] == other_user.ap_id
      assert activity.data["cc"] == [user.ap_id]
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

      assert modified["@context"] ==
               Pleroma.Web.ActivityPub.Utils.make_json_ld_header()["@context"]

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

    test "it strips internal hashtag data" do
      user = insert(:user)

      {:ok, activity} = CommonAPI.post(user, %{"status" => "#2hu"})

      expected_tag = %{
        "href" => Pleroma.Web.Endpoint.url() <> "/tags/2hu",
        "type" => "Hashtag",
        "name" => "#2hu"
      }

      {:ok, modified} = Transmogrifier.prepare_outgoing(activity.data)

      assert modified["object"]["tag"] == [expected_tag]
    end

    test "it strips internal fields" do
      user = insert(:user)

      {:ok, activity} = CommonAPI.post(user, %{"status" => "#2hu :firefox:"})

      {:ok, modified} = Transmogrifier.prepare_outgoing(activity.data)

      assert length(modified["object"]["tag"]) == 2

      assert is_nil(modified["object"]["emoji"])
      assert is_nil(modified["object"]["like_count"])
      assert is_nil(modified["object"]["announcements"])
      assert is_nil(modified["object"]["announcement_count"])
      assert is_nil(modified["object"]["context_id"])
    end

    test "it strips internal fields of article" do
      activity = insert(:article_activity)

      {:ok, modified} = Transmogrifier.prepare_outgoing(activity.data)

      assert length(modified["object"]["tag"]) == 2

      assert is_nil(modified["object"]["emoji"])
      assert is_nil(modified["object"]["like_count"])
      assert is_nil(modified["object"]["announcements"])
      assert is_nil(modified["object"]["announcement_count"])
      assert is_nil(modified["object"]["context_id"])
      assert is_nil(modified["object"]["likes"])
    end

    test "the directMessage flag is present" do
      user = insert(:user)
      other_user = insert(:user)

      {:ok, activity} = CommonAPI.post(user, %{"status" => "2hu :moominmamma:"})

      {:ok, modified} = Transmogrifier.prepare_outgoing(activity.data)

      assert modified["directMessage"] == false

      {:ok, activity} =
        CommonAPI.post(user, %{"status" => "@#{other_user.nickname} :moominmamma:"})

      {:ok, modified} = Transmogrifier.prepare_outgoing(activity.data)

      assert modified["directMessage"] == false

      {:ok, activity} =
        CommonAPI.post(user, %{
          "status" => "@#{other_user.nickname} :moominmamma:",
          "visibility" => "direct"
        })

      {:ok, modified} = Transmogrifier.prepare_outgoing(activity.data)

      assert modified["directMessage"] == true
    end

    test "it strips BCC field" do
      user = insert(:user)
      {:ok, list} = Pleroma.List.create("foo", user)

      {:ok, activity} =
        CommonAPI.post(user, %{"status" => "foobar", "visibility" => "list:#{list.id}"})

      {:ok, modified} = Transmogrifier.prepare_outgoing(activity.data)

      assert is_nil(modified["bcc"])
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

      user = User.get_cached_by_id(user.id)
      assert user.info.note_count == 1

      {:ok, user} = Transmogrifier.upgrade_user_from_ap_id("https://niu.moe/users/rye")
      assert user.info.ap_enabled
      assert user.info.note_count == 1
      assert user.follower_address == "https://niu.moe/users/rye/followers"
      assert user.following_address == "https://niu.moe/users/rye/following"

      user = User.get_cached_by_id(user.id)
      assert user.info.note_count == 1

      activity = Activity.get_by_id(activity.id)
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
             } = user.info.banner

      refute "..." in activity.recipients

      unrelated_activity = Activity.get_by_id(unrelated_activity.id)
      refute user.follower_address in unrelated_activity.recipients

      user_two = User.get_cached_by_id(user_two.id)
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

  describe "actor rewriting" do
    test "it fixes the actor URL property to be a proper URI" do
      data = %{
        "url" => %{"href" => "http://example.com"}
      }

      rewritten = Transmogrifier.maybe_fix_user_object(data)
      assert rewritten["url"] == "http://example.com"
    end
  end

  describe "actor origin containment" do
    test "it rejects activities which reference objects with bogus origins" do
      data = %{
        "@context" => "https://www.w3.org/ns/activitystreams",
        "id" => "http://mastodon.example.org/users/admin/activities/1234",
        "actor" => "http://mastodon.example.org/users/admin",
        "to" => ["https://www.w3.org/ns/activitystreams#Public"],
        "object" => "https://info.pleroma.site/activity.json",
        "type" => "Announce"
      }

      :error = Transmogrifier.handle_incoming(data)
    end

    test "it rejects activities which reference objects that have an incorrect attribution (variant 1)" do
      data = %{
        "@context" => "https://www.w3.org/ns/activitystreams",
        "id" => "http://mastodon.example.org/users/admin/activities/1234",
        "actor" => "http://mastodon.example.org/users/admin",
        "to" => ["https://www.w3.org/ns/activitystreams#Public"],
        "object" => "https://info.pleroma.site/activity2.json",
        "type" => "Announce"
      }

      :error = Transmogrifier.handle_incoming(data)
    end

    test "it rejects activities which reference objects that have an incorrect attribution (variant 2)" do
      data = %{
        "@context" => "https://www.w3.org/ns/activitystreams",
        "id" => "http://mastodon.example.org/users/admin/activities/1234",
        "actor" => "http://mastodon.example.org/users/admin",
        "to" => ["https://www.w3.org/ns/activitystreams#Public"],
        "object" => "https://info.pleroma.site/activity3.json",
        "type" => "Announce"
      }

      :error = Transmogrifier.handle_incoming(data)
    end
  end

  describe "reserialization" do
    test "successfully reserializes a message with inReplyTo == nil" do
      user = insert(:user)

      message = %{
        "@context" => "https://www.w3.org/ns/activitystreams",
        "to" => ["https://www.w3.org/ns/activitystreams#Public"],
        "cc" => [],
        "type" => "Create",
        "object" => %{
          "to" => ["https://www.w3.org/ns/activitystreams#Public"],
          "cc" => [],
          "type" => "Note",
          "content" => "Hi",
          "inReplyTo" => nil,
          "attributedTo" => user.ap_id
        },
        "actor" => user.ap_id
      }

      {:ok, activity} = Transmogrifier.handle_incoming(message)

      {:ok, _} = Transmogrifier.prepare_outgoing(activity.data)
    end

    test "successfully reserializes a message with AS2 objects in IR" do
      user = insert(:user)

      message = %{
        "@context" => "https://www.w3.org/ns/activitystreams",
        "to" => ["https://www.w3.org/ns/activitystreams#Public"],
        "cc" => [],
        "type" => "Create",
        "object" => %{
          "to" => ["https://www.w3.org/ns/activitystreams#Public"],
          "cc" => [],
          "type" => "Note",
          "content" => "Hi",
          "inReplyTo" => nil,
          "attributedTo" => user.ap_id,
          "tag" => [
            %{"name" => "#2hu", "href" => "http://example.com/2hu", "type" => "Hashtag"},
            %{"name" => "Bob", "href" => "http://example.com/bob", "type" => "Mention"}
          ]
        },
        "actor" => user.ap_id
      }

      {:ok, activity} = Transmogrifier.handle_incoming(message)

      {:ok, _} = Transmogrifier.prepare_outgoing(activity.data)
    end
  end

  test "Rewrites Answers to Notes" do
    user = insert(:user)

    {:ok, poll_activity} =
      CommonAPI.post(user, %{
        "status" => "suya...",
        "poll" => %{"options" => ["suya", "suya.", "suya.."], "expires_in" => 10}
      })

    poll_object = Object.normalize(poll_activity)
    # TODO: Replace with CommonAPI vote creation when implemented
    data =
      File.read!("test/fixtures/mastodon-vote.json")
      |> Poison.decode!()
      |> Kernel.put_in(["to"], user.ap_id)
      |> Kernel.put_in(["object", "inReplyTo"], poll_object.data["id"])
      |> Kernel.put_in(["object", "to"], user.ap_id)

    {:ok, %Activity{local: false} = activity} = Transmogrifier.handle_incoming(data)
    {:ok, data} = Transmogrifier.prepare_outgoing(activity.data)

    assert data["object"]["type"] == "Note"
  end

  describe "fix_explicit_addressing" do
    setup do
      user = insert(:user)
      [user: user]
    end

    test "moves non-explicitly mentioned actors to cc", %{user: user} do
      explicitly_mentioned_actors = [
        "https://pleroma.gold/users/user1",
        "https://pleroma.gold/user2"
      ]

      object = %{
        "actor" => user.ap_id,
        "to" => explicitly_mentioned_actors ++ ["https://social.beepboop.ga/users/dirb"],
        "cc" => [],
        "tag" =>
          Enum.map(explicitly_mentioned_actors, fn href ->
            %{"type" => "Mention", "href" => href}
          end)
      }

      fixed_object = Transmogrifier.fix_explicit_addressing(object)
      assert Enum.all?(explicitly_mentioned_actors, &(&1 in fixed_object["to"]))
      refute "https://social.beepboop.ga/users/dirb" in fixed_object["to"]
      assert "https://social.beepboop.ga/users/dirb" in fixed_object["cc"]
    end

    test "does not move actor's follower collection to cc", %{user: user} do
      object = %{
        "actor" => user.ap_id,
        "to" => [user.follower_address],
        "cc" => []
      }

      fixed_object = Transmogrifier.fix_explicit_addressing(object)
      assert user.follower_address in fixed_object["to"]
      refute user.follower_address in fixed_object["cc"]
    end

    test "removes recipient's follower collection from cc", %{user: user} do
      recipient = insert(:user)

      object = %{
        "actor" => user.ap_id,
        "to" => [recipient.ap_id, "https://www.w3.org/ns/activitystreams#Public"],
        "cc" => [user.follower_address, recipient.follower_address]
      }

      fixed_object = Transmogrifier.fix_explicit_addressing(object)

      assert user.follower_address in fixed_object["cc"]
      refute recipient.follower_address in fixed_object["cc"]
      refute recipient.follower_address in fixed_object["to"]
    end
  end
end
