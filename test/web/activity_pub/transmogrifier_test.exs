# Pleroma: A lightweight social networking server
# Copyright © 2017-2019 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.ActivityPub.TransmogrifierTest do
  use Pleroma.DataCase
  alias Pleroma.Activity
  alias Pleroma.Object
  alias Pleroma.Object.Fetcher
  alias Pleroma.Tests.ObanHelpers
  alias Pleroma.User
  alias Pleroma.Web.ActivityPub.ActivityPub
  alias Pleroma.Web.ActivityPub.Transmogrifier
  alias Pleroma.Web.AdminAPI.AccountView
  alias Pleroma.Web.CommonAPI

  import Mock
  import Pleroma.Factory
  import ExUnit.CaptureLog

  setup_all do
    Tesla.Mock.mock_global(fn env -> apply(HttpRequestMock, :request, [env]) end)
    :ok
  end

  clear_config([:instance, :max_remote_account_fields])

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

    @tag capture_log: true
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
             end) =~ "[error] Couldn't fetch \"https://404.site/whatever\", error: nil"
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

      assert user.note_count == 1
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

    test "it works for incoming listens" do
      data = %{
        "@context" => "https://www.w3.org/ns/activitystreams",
        "to" => ["https://www.w3.org/ns/activitystreams#Public"],
        "cc" => [],
        "type" => "Listen",
        "id" => "http://mastodon.example.org/users/admin/listens/1234/activity",
        "actor" => "http://mastodon.example.org/users/admin",
        "object" => %{
          "type" => "Audio",
          "id" => "http://mastodon.example.org/users/admin/listens/1234",
          "attributedTo" => "http://mastodon.example.org/users/admin",
          "title" => "lain radio episode 1",
          "artist" => "lain",
          "album" => "lain radio",
          "length" => 180_000
        }
      }

      {:ok, %Activity{local: false} = activity} = Transmogrifier.handle_incoming(data)

      object = Object.normalize(activity)

      assert object.data["title"] == "lain radio episode 1"
      assert object.data["artist"] == "lain"
      assert object.data["album"] == "lain radio"
      assert object.data["length"] == 180_000
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

    test "it works for incoming misskey likes, turning them into EmojiReactions" do
      user = insert(:user)
      {:ok, activity} = CommonAPI.post(user, %{"status" => "hello"})

      data =
        File.read!("test/fixtures/misskey-like.json")
        |> Poison.decode!()
        |> Map.put("object", activity.data["object"])

      {:ok, %Activity{data: data, local: false}} = Transmogrifier.handle_incoming(data)

      assert data["actor"] == data["actor"]
      assert data["type"] == "EmojiReaction"
      assert data["id"] == data["id"]
      assert data["object"] == activity.data["object"]
      assert data["content"] == "🍮"
    end

    test "it works for incoming misskey likes that contain unicode emojis, turning them into EmojiReactions" do
      user = insert(:user)
      {:ok, activity} = CommonAPI.post(user, %{"status" => "hello"})

      data =
        File.read!("test/fixtures/misskey-like.json")
        |> Poison.decode!()
        |> Map.put("object", activity.data["object"])
        |> Map.put("_misskey_reaction", "⭐")

      {:ok, %Activity{data: data, local: false}} = Transmogrifier.handle_incoming(data)

      assert data["actor"] == data["actor"]
      assert data["type"] == "EmojiReaction"
      assert data["id"] == data["id"]
      assert data["object"] == activity.data["object"]
      assert data["content"] == "⭐"
    end

    test "it works for incoming emoji reactions" do
      user = insert(:user)
      {:ok, activity} = CommonAPI.post(user, %{"status" => "hello"})

      data =
        File.read!("test/fixtures/emoji-reaction.json")
        |> Poison.decode!()
        |> Map.put("object", activity.data["object"])

      {:ok, %Activity{data: data, local: false}} = Transmogrifier.handle_incoming(data)

      assert data["actor"] == "http://mastodon.example.org/users/admin"
      assert data["type"] == "EmojiReaction"
      assert data["id"] == "http://mastodon.example.org/users/admin#reactions/2"
      assert data["object"] == activity.data["object"]
      assert data["content"] == "👌"
    end

    test "it reject invalid emoji reactions" do
      user = insert(:user)
      {:ok, activity} = CommonAPI.post(user, %{"status" => "hello"})

      data =
        File.read!("test/fixtures/emoji-reaction-too-long.json")
        |> Poison.decode!()
        |> Map.put("object", activity.data["object"])

      assert :error = Transmogrifier.handle_incoming(data)

      data =
        File.read!("test/fixtures/emoji-reaction-no-emoji.json")
        |> Poison.decode!()
        |> Map.put("object", activity.data["object"])

      assert :error = Transmogrifier.handle_incoming(data)
    end

    test "it works for incoming emoji reaction undos" do
      user = insert(:user)

      {:ok, activity} = CommonAPI.post(user, %{"status" => "hello"})
      {:ok, reaction_activity, _object} = CommonAPI.react_with_emoji(activity.id, user, "👌")

      data =
        File.read!("test/fixtures/mastodon-undo-like.json")
        |> Poison.decode!()
        |> Map.put("object", reaction_activity.data["id"])
        |> Map.put("actor", user.ap_id)

      {:ok, activity} = Transmogrifier.handle_incoming(data)

      assert activity.actor == user.ap_id
      assert activity.data["id"] == data["id"]
      assert activity.data["type"] == "Undo"
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

    test "it works for incoming unlikes with an existing like activity and a compact object" do
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
        |> Map.put("object", like_data["id"])
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

    test "it works for incoming announces with an inlined activity" do
      data =
        File.read!("test/fixtures/mastodon-announce-private.json")
        |> Poison.decode!()

      {:ok, %Activity{data: data, local: false}} = Transmogrifier.handle_incoming(data)

      assert data["actor"] == "http://mastodon.example.org/users/admin"
      assert data["type"] == "Announce"

      assert data["id"] ==
               "http://mastodon.example.org/users/admin/statuses/99542391527669785/activity"

      object = Object.normalize(data["object"])

      assert object.data["id"] == "http://mastodon.example.org/@admin/99541947525187368"
      assert object.data["content"] == "this is a private toot"
    end

    @tag capture_log: true
    test "it rejects incoming announces with an inlined activity from another origin" do
      data =
        File.read!("test/fixtures/bogus-mastodon-announce.json")
        |> Poison.decode!()

      assert :error = Transmogrifier.handle_incoming(data)
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

    test "it strips internal reactions" do
      user = insert(:user)
      {:ok, activity} = CommonAPI.post(user, %{"status" => "#cofe"})
      {:ok, _, _} = CommonAPI.react_with_emoji(activity.id, user, "📢")

      %{object: object} = Activity.get_by_id_with_object(activity.id)
      assert Map.has_key?(object.data, "reactions")
      assert Map.has_key?(object.data, "reaction_count")

      object_data = Transmogrifier.strip_internal_fields(object.data)
      refute Map.has_key?(object_data, "reactions")
      refute Map.has_key?(object_data, "reaction_count")
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

      assert data["id"] == update_data["id"]

      user = User.get_cached_by_ap_id(data["actor"])
      assert user.name == "gargle"

      assert user.avatar["url"] == [
               %{
                 "href" =>
                   "https://cd.niu.moe/accounts/avatars/000/033/323/original/fd7f8ae0b3ffedc9.jpeg"
               }
             ]

      assert user.banner["url"] == [
               %{
                 "href" =>
                   "https://cd.niu.moe/accounts/headers/000/033/323/original/850b3448fa5fd477.png"
               }
             ]

      assert user.bio == "<p>Some bio</p>"
    end

    test "it works with alsoKnownAs" do
      {:ok, %Activity{data: %{"actor" => actor}}} =
        "test/fixtures/mastodon-post-activity.json"
        |> File.read!()
        |> Poison.decode!()
        |> Transmogrifier.handle_incoming()

      assert User.get_cached_by_ap_id(actor).also_known_as == ["http://example.org/users/foo"]

      {:ok, _activity} =
        "test/fixtures/mastodon-update.json"
        |> File.read!()
        |> Poison.decode!()
        |> Map.put("actor", actor)
        |> Map.update!("object", fn object ->
          object
          |> Map.put("actor", actor)
          |> Map.put("id", actor)
          |> Map.put("alsoKnownAs", [
            "http://mastodon.example.org/users/foo",
            "http://example.org/users/bar"
          ])
        end)
        |> Transmogrifier.handle_incoming()

      assert User.get_cached_by_ap_id(actor).also_known_as == [
               "http://mastodon.example.org/users/foo",
               "http://example.org/users/bar"
             ]
    end

    test "it works with custom profile fields" do
      {:ok, activity} =
        "test/fixtures/mastodon-post-activity.json"
        |> File.read!()
        |> Poison.decode!()
        |> Transmogrifier.handle_incoming()

      user = User.get_cached_by_ap_id(activity.actor)

      assert User.fields(user) == [
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

      assert User.fields(user) == [
               %{"name" => "foo", "value" => "updated"},
               %{"name" => "foo1", "value" => "updated"}
             ]

      Pleroma.Config.put([:instance, :max_remote_account_fields], 2)

      update_data =
        put_in(update_data, ["object", "attachment"], [
          %{"name" => "foo", "type" => "PropertyValue", "value" => "bar"},
          %{"name" => "foo11", "type" => "PropertyValue", "value" => "bar11"},
          %{"name" => "foo22", "type" => "PropertyValue", "value" => "bar22"}
        ])

      {:ok, _} = Transmogrifier.handle_incoming(update_data)

      user = User.get_cached_by_ap_id(user.ap_id)

      assert User.fields(user) == [
               %{"name" => "foo", "value" => "updated"},
               %{"name" => "foo1", "value" => "updated"}
             ]

      update_data = put_in(update_data, ["object", "attachment"], [])

      {:ok, _} = Transmogrifier.handle_incoming(update_data)

      user = User.get_cached_by_ap_id(user.ap_id)

      assert User.fields(user) == []
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
      assert user.locked == true
    end

    test "it works for incoming deletes" do
      activity = insert(:note_activity)
      deleting_user = insert(:user)

      data =
        File.read!("test/fixtures/mastodon-delete.json")
        |> Poison.decode!()

      object =
        data["object"]
        |> Map.put("id", activity.data["object"])

      data =
        data
        |> Map.put("object", object)
        |> Map.put("actor", deleting_user.ap_id)

      {:ok, %Activity{actor: actor, local: false, data: %{"id" => id}}} =
        Transmogrifier.handle_incoming(data)

      assert id == data["id"]
      refute Activity.get_by_id(activity.id)
      assert actor == deleting_user.ap_id
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
               "[error] Could not decode user at fetch http://mastodon.example.org/users/gargron, {:error, :nxdomain}"

      assert Activity.get_by_id(activity.id)
    end

    @tag capture_log: true
    test "it works for incoming user deletes" do
      %{ap_id: ap_id} = insert(:user, ap_id: "http://mastodon.example.org/users/admin")

      data =
        File.read!("test/fixtures/mastodon-delete-user.json")
        |> Poison.decode!()

      {:ok, _} = Transmogrifier.handle_incoming(data)
      ObanHelpers.perform_all()

      refute User.get_cached_by_ap_id(ap_id)
    end

    test "it fails for incoming user deletes with spoofed origin" do
      %{ap_id: ap_id} = insert(:user)

      data =
        File.read!("test/fixtures/mastodon-delete-user.json")
        |> Poison.decode!()
        |> Map.put("actor", ap_id)

      assert capture_log(fn ->
               assert :error == Transmogrifier.handle_incoming(data)
             end) =~ "Object containment failed"

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

    test "it works for incoming follows to locked account" do
      pending_follower = insert(:user, ap_id: "http://mastodon.example.org/users/admin")
      user = insert(:user, locked: true)

      data =
        File.read!("test/fixtures/mastodon-follow-activity.json")
        |> Poison.decode!()
        |> Map.put("object", user.ap_id)

      {:ok, %Activity{data: data, local: false}} = Transmogrifier.handle_incoming(data)

      assert data["type"] == "Follow"
      assert data["object"] == user.ap_id
      assert data["state"] == "pending"
      assert data["actor"] == "http://mastodon.example.org/users/admin"

      assert [^pending_follower] = User.get_follow_requests(user)
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

      assert activity.data["id"] == accept_data["id"]

      follower = User.get_cached_by_id(follower.id)

      assert User.following?(follower, followed) == true
    end

    test "it works for incoming accepts which were orphaned" do
      follower = insert(:user)
      followed = insert(:user, locked: true)

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
      followed = insert(:user, locked: true)

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
      followed = insert(:user, locked: true)

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
      followed = insert(:user, locked: true)

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
      followed = insert(:user, locked: true)

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
      assert activity.data["id"] == reject_data["id"]

      follower = User.get_cached_by_id(follower.id)

      assert User.following?(follower, followed) == false
    end

    test "it works for incoming rejects which are referenced by IRI only" do
      follower = insert(:user)
      followed = insert(:user, locked: true)

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

      note_obj = %{
        "type" => "Note",
        "id" => activity.data["id"],
        "content" => "test post",
        "published" => object.data["published"],
        "actor" => AccountView.render("show.json", %{user: user})
      }

      message = %{
        "@context" => "https://www.w3.org/ns/activitystreams",
        "cc" => [user.ap_id],
        "object" => [user.ap_id, activity.data["id"]],
        "type" => "Flag",
        "content" => "blocked AND reported!!!",
        "actor" => other_user.ap_id
      }

      assert {:ok, activity} = Transmogrifier.handle_incoming(message)

      assert activity.data["object"] == [user.ap_id, note_obj]
      assert activity.data["content"] == "blocked AND reported!!!"
      assert activity.data["actor"] == other_user.ap_id
      assert activity.data["cc"] == [user.ap_id]
    end

    test "it correctly processes messages with non-array to field" do
      user = insert(:user)

      message = %{
        "@context" => "https://www.w3.org/ns/activitystreams",
        "to" => "https://www.w3.org/ns/activitystreams#Public",
        "type" => "Create",
        "object" => %{
          "content" => "blah blah blah",
          "type" => "Note",
          "attributedTo" => user.ap_id,
          "inReplyTo" => nil
        },
        "actor" => user.ap_id
      }

      assert {:ok, activity} = Transmogrifier.handle_incoming(message)

      assert ["https://www.w3.org/ns/activitystreams#Public"] == activity.data["to"]
    end

    test "it correctly processes messages with non-array cc field" do
      user = insert(:user)

      message = %{
        "@context" => "https://www.w3.org/ns/activitystreams",
        "to" => user.follower_address,
        "cc" => "https://www.w3.org/ns/activitystreams#Public",
        "type" => "Create",
        "object" => %{
          "content" => "blah blah blah",
          "type" => "Note",
          "attributedTo" => user.ap_id,
          "inReplyTo" => nil
        },
        "actor" => user.ap_id
      }

      assert {:ok, activity} = Transmogrifier.handle_incoming(message)

      assert ["https://www.w3.org/ns/activitystreams#Public"] == activity.data["cc"]
      assert [user.follower_address] == activity.data["to"]
    end

    test "it accepts Move activities" do
      old_user = insert(:user)
      new_user = insert(:user)

      message = %{
        "@context" => "https://www.w3.org/ns/activitystreams",
        "type" => "Move",
        "actor" => old_user.ap_id,
        "object" => old_user.ap_id,
        "target" => new_user.ap_id
      }

      assert :error = Transmogrifier.handle_incoming(message)

      {:ok, _new_user} = User.update_and_set_cache(new_user, %{also_known_as: [old_user.ap_id]})

      assert {:ok, %Activity{} = activity} = Transmogrifier.handle_incoming(message)
      assert activity.actor == old_user.ap_id
      assert activity.data["actor"] == old_user.ap_id
      assert activity.data["object"] == old_user.ap_id
      assert activity.data["target"] == new_user.ap_id
      assert activity.data["type"] == "Move"
    end
  end

  describe "prepare outgoing" do
    test "it inlines private announced objects" do
      user = insert(:user)

      {:ok, activity} = CommonAPI.post(user, %{"status" => "hey", "visibility" => "private"})

      {:ok, announce_activity, _} = CommonAPI.repeat(activity.id, user)

      {:ok, modified} = Transmogrifier.prepare_outgoing(announce_activity.data)

      assert modified["object"]["content"] == "hey"
      assert modified["object"]["actor"] == modified["object"]["attributedTo"]
    end

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

    test "it can handle Listen activities" do
      listen_activity = insert(:listen)

      {:ok, modified} = Transmogrifier.prepare_outgoing(listen_activity.data)

      assert modified["type"] == "Listen"

      user = insert(:user)

      {:ok, activity} = CommonAPI.listen(user, %{"title" => "lain radio episode 1"})

      {:ok, _modified} = Transmogrifier.prepare_outgoing(activity.data)
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

      user_two = insert(:user)
      Pleroma.FollowingRelationship.follow(user_two, user, "accept")

      {:ok, activity} = CommonAPI.post(user, %{"status" => "test"})
      {:ok, unrelated_activity} = CommonAPI.post(user_two, %{"status" => "test"})
      assert "http://localhost:4001/users/rye@niu.moe/followers" in activity.recipients

      user = User.get_cached_by_id(user.id)
      assert user.note_count == 1

      {:ok, user} = Transmogrifier.upgrade_user_from_ap_id("https://niu.moe/users/rye")
      ObanHelpers.perform_all()

      assert user.ap_enabled
      assert user.note_count == 1
      assert user.follower_address == "https://niu.moe/users/rye/followers"
      assert user.following_address == "https://niu.moe/users/rye/following"

      user = User.get_cached_by_id(user.id)
      assert user.note_count == 1

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
             } = user.banner

      refute "..." in activity.recipients

      unrelated_activity = Activity.get_by_id(unrelated_activity.id)
      refute user.follower_address in unrelated_activity.recipients

      user_two = User.get_cached_by_id(user_two.id)
      assert User.following?(user_two, user)
      refute "..." in User.following(user_two)
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

      assert capture_log(fn ->
               :error = Transmogrifier.handle_incoming(data)
             end) =~ "Object containment failed"
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

      assert capture_log(fn ->
               :error = Transmogrifier.handle_incoming(data)
             end) =~ "Object containment failed"
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

      assert capture_log(fn ->
               :error = Transmogrifier.handle_incoming(data)
             end) =~ "Object containment failed"
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

  describe "fix_summary/1" do
    test "returns fixed object" do
      assert Transmogrifier.fix_summary(%{"summary" => nil}) == %{"summary" => ""}
      assert Transmogrifier.fix_summary(%{"summary" => "ok"}) == %{"summary" => "ok"}
      assert Transmogrifier.fix_summary(%{}) == %{"summary" => ""}
    end
  end

  describe "fix_in_reply_to/2" do
    clear_config([:instance, :federation_incoming_replies_max_depth])

    setup do
      data = Poison.decode!(File.read!("test/fixtures/mastodon-post-activity.json"))
      [data: data]
    end

    test "returns not modified object when hasn't containts inReplyTo field", %{data: data} do
      assert Transmogrifier.fix_in_reply_to(data) == data
    end

    test "returns object with inReplyToAtomUri when denied incoming reply", %{data: data} do
      Pleroma.Config.put([:instance, :federation_incoming_replies_max_depth], 0)

      object_with_reply =
        Map.put(data["object"], "inReplyTo", "https://shitposter.club/notice/2827873")

      modified_object = Transmogrifier.fix_in_reply_to(object_with_reply)
      assert modified_object["inReplyTo"] == "https://shitposter.club/notice/2827873"
      assert modified_object["inReplyToAtomUri"] == "https://shitposter.club/notice/2827873"

      object_with_reply =
        Map.put(data["object"], "inReplyTo", %{"id" => "https://shitposter.club/notice/2827873"})

      modified_object = Transmogrifier.fix_in_reply_to(object_with_reply)
      assert modified_object["inReplyTo"] == %{"id" => "https://shitposter.club/notice/2827873"}
      assert modified_object["inReplyToAtomUri"] == "https://shitposter.club/notice/2827873"

      object_with_reply =
        Map.put(data["object"], "inReplyTo", ["https://shitposter.club/notice/2827873"])

      modified_object = Transmogrifier.fix_in_reply_to(object_with_reply)
      assert modified_object["inReplyTo"] == ["https://shitposter.club/notice/2827873"]
      assert modified_object["inReplyToAtomUri"] == "https://shitposter.club/notice/2827873"

      object_with_reply = Map.put(data["object"], "inReplyTo", [])
      modified_object = Transmogrifier.fix_in_reply_to(object_with_reply)
      assert modified_object["inReplyTo"] == []
      assert modified_object["inReplyToAtomUri"] == ""
    end

    @tag capture_log: true
    test "returns modified object when allowed incoming reply", %{data: data} do
      object_with_reply =
        Map.put(
          data["object"],
          "inReplyTo",
          "https://shitposter.club/notice/2827873"
        )

      Pleroma.Config.put([:instance, :federation_incoming_replies_max_depth], 5)
      modified_object = Transmogrifier.fix_in_reply_to(object_with_reply)

      assert modified_object["inReplyTo"] ==
               "tag:shitposter.club,2017-05-05:noticeId=2827873:objectType=comment"

      assert modified_object["inReplyToAtomUri"] == "https://shitposter.club/notice/2827873"

      assert modified_object["conversation"] ==
               "tag:shitposter.club,2017-05-05:objectType=thread:nonce=3c16e9c2681f6d26"

      assert modified_object["context"] ==
               "tag:shitposter.club,2017-05-05:objectType=thread:nonce=3c16e9c2681f6d26"
    end
  end

  describe "fix_url/1" do
    test "fixes data for object when url is map" do
      object = %{
        "url" => %{
          "type" => "Link",
          "mimeType" => "video/mp4",
          "href" => "https://peede8d-46fb-ad81-2d4c2d1630e3-480.mp4"
        }
      }

      assert Transmogrifier.fix_url(object) == %{
               "url" => "https://peede8d-46fb-ad81-2d4c2d1630e3-480.mp4"
             }
    end

    test "fixes data for video object" do
      object = %{
        "type" => "Video",
        "url" => [
          %{
            "type" => "Link",
            "mimeType" => "video/mp4",
            "href" => "https://peede8d-46fb-ad81-2d4c2d1630e3-480.mp4"
          },
          %{
            "type" => "Link",
            "mimeType" => "video/mp4",
            "href" => "https://peertube46fb-ad81-2d4c2d1630e3-240.mp4"
          },
          %{
            "type" => "Link",
            "mimeType" => "text/html",
            "href" => "https://peertube.-2d4c2d1630e3"
          },
          %{
            "type" => "Link",
            "mimeType" => "text/html",
            "href" => "https://peertube.-2d4c2d16377-42"
          }
        ]
      }

      assert Transmogrifier.fix_url(object) == %{
               "attachment" => [
                 %{
                   "href" => "https://peede8d-46fb-ad81-2d4c2d1630e3-480.mp4",
                   "mimeType" => "video/mp4",
                   "type" => "Link"
                 }
               ],
               "type" => "Video",
               "url" => "https://peertube.-2d4c2d1630e3"
             }
    end

    test "fixes url for not Video object" do
      object = %{
        "type" => "Text",
        "url" => [
          %{
            "type" => "Link",
            "mimeType" => "text/html",
            "href" => "https://peertube.-2d4c2d1630e3"
          },
          %{
            "type" => "Link",
            "mimeType" => "text/html",
            "href" => "https://peertube.-2d4c2d16377-42"
          }
        ]
      }

      assert Transmogrifier.fix_url(object) == %{
               "type" => "Text",
               "url" => "https://peertube.-2d4c2d1630e3"
             }

      assert Transmogrifier.fix_url(%{"type" => "Text", "url" => []}) == %{
               "type" => "Text",
               "url" => ""
             }
    end

    test "retunrs not modified object" do
      assert Transmogrifier.fix_url(%{"type" => "Text"}) == %{"type" => "Text"}
    end
  end

  describe "get_obj_helper/2" do
    test "returns nil when cannot normalize object" do
      assert capture_log(fn ->
               refute Transmogrifier.get_obj_helper("test-obj-id")
             end) =~ "Unsupported URI scheme"
    end

    @tag capture_log: true
    test "returns {:ok, %Object{}} for success case" do
      assert {:ok, %Object{}} =
               Transmogrifier.get_obj_helper("https://shitposter.club/notice/2827873")
    end
  end

  describe "fix_attachments/1" do
    test "returns not modified object" do
      data = Poison.decode!(File.read!("test/fixtures/mastodon-post-activity.json"))
      assert Transmogrifier.fix_attachments(data) == data
    end

    test "returns modified object when attachment is map" do
      assert Transmogrifier.fix_attachments(%{
               "attachment" => %{
                 "mediaType" => "video/mp4",
                 "url" => "https://peertube.moe/stat-480.mp4"
               }
             }) == %{
               "attachment" => [
                 %{
                   "mediaType" => "video/mp4",
                   "url" => [
                     %{
                       "href" => "https://peertube.moe/stat-480.mp4",
                       "mediaType" => "video/mp4",
                       "type" => "Link"
                     }
                   ]
                 }
               ]
             }
    end

    test "returns modified object when attachment is list" do
      assert Transmogrifier.fix_attachments(%{
               "attachment" => [
                 %{"mediaType" => "video/mp4", "url" => "https://pe.er/stat-480.mp4"},
                 %{"mimeType" => "video/mp4", "href" => "https://pe.er/stat-480.mp4"}
               ]
             }) == %{
               "attachment" => [
                 %{
                   "mediaType" => "video/mp4",
                   "url" => [
                     %{
                       "href" => "https://pe.er/stat-480.mp4",
                       "mediaType" => "video/mp4",
                       "type" => "Link"
                     }
                   ]
                 },
                 %{
                   "href" => "https://pe.er/stat-480.mp4",
                   "mediaType" => "video/mp4",
                   "mimeType" => "video/mp4",
                   "url" => [
                     %{
                       "href" => "https://pe.er/stat-480.mp4",
                       "mediaType" => "video/mp4",
                       "type" => "Link"
                     }
                   ]
                 }
               ]
             }
    end
  end

  describe "fix_emoji/1" do
    test "returns not modified object when object not contains tags" do
      data = Poison.decode!(File.read!("test/fixtures/mastodon-post-activity.json"))
      assert Transmogrifier.fix_emoji(data) == data
    end

    test "returns object with emoji when object contains list tags" do
      assert Transmogrifier.fix_emoji(%{
               "tag" => [
                 %{"type" => "Emoji", "name" => ":bib:", "icon" => %{"url" => "/test"}},
                 %{"type" => "Hashtag"}
               ]
             }) == %{
               "emoji" => %{"bib" => "/test"},
               "tag" => [
                 %{"icon" => %{"url" => "/test"}, "name" => ":bib:", "type" => "Emoji"},
                 %{"type" => "Hashtag"}
               ]
             }
    end

    test "returns object with emoji when object contains map tag" do
      assert Transmogrifier.fix_emoji(%{
               "tag" => %{"type" => "Emoji", "name" => ":bib:", "icon" => %{"url" => "/test"}}
             }) == %{
               "emoji" => %{"bib" => "/test"},
               "tag" => %{"icon" => %{"url" => "/test"}, "name" => ":bib:", "type" => "Emoji"}
             }
    end
  end
end
