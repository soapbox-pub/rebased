# Pleroma: A lightweight social networking server
# Copyright © 2017-2018 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.OStatusTest do
  use Pleroma.DataCase
  alias Pleroma.Activity
  alias Pleroma.Instances
  alias Pleroma.Object
  alias Pleroma.Repo
  alias Pleroma.User
  alias Pleroma.Web.OStatus
  alias Pleroma.Web.XML

  import ExUnit.CaptureLog
  import Mock
  import Pleroma.Factory

  setup_all do
    Tesla.Mock.mock_global(fn env -> apply(HttpRequestMock, :request, [env]) end)
    :ok
  end

  test "don't insert create notes twice" do
    incoming = File.read!("test/fixtures/incoming_note_activity.xml")
    {:ok, [activity]} = OStatus.handle_incoming(incoming)
    assert {:ok, [activity]} == OStatus.handle_incoming(incoming)
  end

  test "handle incoming note - GS, Salmon" do
    incoming = File.read!("test/fixtures/incoming_note_activity.xml")
    {:ok, [activity]} = OStatus.handle_incoming(incoming)
    object = Object.normalize(activity.data["object"])

    user = User.get_cached_by_ap_id(activity.data["actor"])
    assert user.info.note_count == 1
    assert activity.data["type"] == "Create"
    assert object.data["type"] == "Note"

    assert object.data["id"] == "tag:gs.example.org:4040,2017-04-23:noticeId=29:objectType=note"

    assert activity.data["published"] == "2017-04-23T14:51:03+00:00"
    assert object.data["published"] == "2017-04-23T14:51:03+00:00"

    assert activity.data["context"] ==
             "tag:gs.example.org:4040,2017-04-23:objectType=thread:nonce=f09e22f58abd5c7b"

    assert "http://pleroma.example.org:4000/users/lain3" in activity.data["to"]
    assert object.data["emoji"] == %{"marko" => "marko.png", "reimu" => "reimu.png"}
    assert activity.local == false
  end

  test "handle incoming notes - GS, subscription" do
    incoming = File.read!("test/fixtures/ostatus_incoming_post.xml")
    {:ok, [activity]} = OStatus.handle_incoming(incoming)
    object = Object.normalize(activity.data["object"])

    assert activity.data["type"] == "Create"
    assert object.data["type"] == "Note"
    assert object.data["actor"] == "https://social.heldscal.la/user/23211"
    assert object.data["content"] == "Will it blend?"
    user = User.get_cached_by_ap_id(activity.data["actor"])
    assert User.ap_followers(user) in activity.data["to"]
    assert "https://www.w3.org/ns/activitystreams#Public" in activity.data["to"]
  end

  test "handle incoming notes with attachments - GS, subscription" do
    incoming = File.read!("test/fixtures/incoming_websub_gnusocial_attachments.xml")
    {:ok, [activity]} = OStatus.handle_incoming(incoming)
    object = Object.normalize(activity.data["object"])

    assert activity.data["type"] == "Create"
    assert object.data["type"] == "Note"
    assert object.data["actor"] == "https://social.heldscal.la/user/23211"
    assert object.data["attachment"] |> length == 2
    assert object.data["external_url"] == "https://social.heldscal.la/notice/2020923"
    assert "https://www.w3.org/ns/activitystreams#Public" in activity.data["to"]
  end

  test "handle incoming notes with tags" do
    incoming = File.read!("test/fixtures/ostatus_incoming_post_tag.xml")
    {:ok, [activity]} = OStatus.handle_incoming(incoming)
    object = Object.normalize(activity.data["object"])

    assert object.data["tag"] == ["nsfw"]
    assert "https://www.w3.org/ns/activitystreams#Public" in activity.data["to"]
  end

  test "handle incoming notes - Mastodon, salmon, reply" do
    # It uses the context of the replied to object
    Repo.insert!(%Object{
      data: %{
        "id" => "https://pleroma.soykaf.com/objects/c237d966-ac75-4fe3-a87a-d89d71a3a7a4",
        "context" => "2hu"
      }
    })

    incoming = File.read!("test/fixtures/incoming_reply_mastodon.xml")
    {:ok, [activity]} = OStatus.handle_incoming(incoming)
    object = Object.normalize(activity.data["object"])

    assert activity.data["type"] == "Create"
    assert object.data["type"] == "Note"
    assert object.data["actor"] == "https://mastodon.social/users/lambadalambda"
    assert activity.data["context"] == "2hu"
    assert "https://www.w3.org/ns/activitystreams#Public" in activity.data["to"]
  end

  test "handle incoming notes - Mastodon, with CW" do
    incoming = File.read!("test/fixtures/mastodon-note-cw.xml")
    {:ok, [activity]} = OStatus.handle_incoming(incoming)
    object = Object.normalize(activity.data["object"])

    assert activity.data["type"] == "Create"
    assert object.data["type"] == "Note"
    assert object.data["actor"] == "https://mastodon.social/users/lambadalambda"
    assert object.data["summary"] == "technologic"
    assert "https://www.w3.org/ns/activitystreams#Public" in activity.data["to"]
  end

  test "handle incoming unlisted messages, put public into cc" do
    incoming = File.read!("test/fixtures/mastodon-note-unlisted.xml")
    {:ok, [activity]} = OStatus.handle_incoming(incoming)
    object = Object.normalize(activity.data["object"])

    refute "https://www.w3.org/ns/activitystreams#Public" in activity.data["to"]
    assert "https://www.w3.org/ns/activitystreams#Public" in activity.data["cc"]
    refute "https://www.w3.org/ns/activitystreams#Public" in object.data["to"]
    assert "https://www.w3.org/ns/activitystreams#Public" in object.data["cc"]
  end

  test "handle incoming retweets - Mastodon, with CW" do
    incoming = File.read!("test/fixtures/cw_retweet.xml")
    {:ok, [[_activity, retweeted_activity]]} = OStatus.handle_incoming(incoming)
    retweeted_object = Object.normalize(retweeted_activity.data["object"])

    assert retweeted_object.data["summary"] == "Hey."
  end

  test "handle incoming notes - GS, subscription, reply" do
    incoming = File.read!("test/fixtures/ostatus_incoming_reply.xml")
    {:ok, [activity]} = OStatus.handle_incoming(incoming)
    object = Object.normalize(activity.data["object"])

    assert activity.data["type"] == "Create"
    assert object.data["type"] == "Note"
    assert object.data["actor"] == "https://social.heldscal.la/user/23211"

    assert object.data["content"] ==
             "@<a href=\"https://gs.archae.me/user/4687\" class=\"h-card u-url p-nickname mention\" title=\"shpbot\">shpbot</a> why not indeed."

    assert object.data["inReplyTo"] ==
             "tag:gs.archae.me,2017-04-30:noticeId=778260:objectType=note"

    assert "https://www.w3.org/ns/activitystreams#Public" in activity.data["to"]
  end

  test "handle incoming retweets - GS, subscription" do
    incoming = File.read!("test/fixtures/share-gs.xml")
    {:ok, [[activity, retweeted_activity]]} = OStatus.handle_incoming(incoming)

    assert activity.data["type"] == "Announce"
    assert activity.data["actor"] == "https://social.heldscal.la/user/23211"
    assert activity.data["object"] == retweeted_activity.data["object"]
    assert "https://pleroma.soykaf.com/users/lain" in activity.data["to"]
    refute activity.local

    retweeted_activity = Activity.get_by_id(retweeted_activity.id)
    retweeted_object = Object.normalize(retweeted_activity.data["object"])
    assert retweeted_activity.data["type"] == "Create"
    assert retweeted_activity.data["actor"] == "https://pleroma.soykaf.com/users/lain"
    refute retweeted_activity.local
    assert retweeted_object.data["announcement_count"] == 1
    assert String.contains?(retweeted_object.data["content"], "mastodon")
    refute String.contains?(retweeted_object.data["content"], "Test account")
  end

  test "handle incoming retweets - GS, subscription - local message" do
    incoming = File.read!("test/fixtures/share-gs-local.xml")
    note_activity = insert(:note_activity)
    user = User.get_cached_by_ap_id(note_activity.data["actor"])

    incoming =
      incoming
      |> String.replace("LOCAL_ID", note_activity.data["object"]["id"])
      |> String.replace("LOCAL_USER", user.ap_id)

    {:ok, [[activity, retweeted_activity]]} = OStatus.handle_incoming(incoming)

    assert activity.data["type"] == "Announce"
    assert activity.data["actor"] == "https://social.heldscal.la/user/23211"
    assert activity.data["object"] == retweeted_activity.data["object"]["id"]
    assert user.ap_id in activity.data["to"]
    refute activity.local

    retweeted_activity = Activity.get_by_id(retweeted_activity.id)
    assert note_activity.id == retweeted_activity.id
    assert retweeted_activity.data["type"] == "Create"
    assert retweeted_activity.data["actor"] == user.ap_id
    assert retweeted_activity.local
    assert retweeted_activity.data["object"]["announcement_count"] == 1
  end

  test "handle incoming retweets - Mastodon, salmon" do
    incoming = File.read!("test/fixtures/share.xml")
    {:ok, [[activity, retweeted_activity]]} = OStatus.handle_incoming(incoming)
    retweeted_object = Object.normalize(retweeted_activity.data["object"])

    assert activity.data["type"] == "Announce"
    assert activity.data["actor"] == "https://mastodon.social/users/lambadalambda"
    assert activity.data["object"] == retweeted_activity.data["object"]

    assert activity.data["id"] ==
             "tag:mastodon.social,2017-05-03:objectId=4934452:objectType=Status"

    refute activity.local
    assert retweeted_activity.data["type"] == "Create"
    assert retweeted_activity.data["actor"] == "https://pleroma.soykaf.com/users/lain"
    refute retweeted_activity.local
    refute String.contains?(retweeted_object.data["content"], "Test account")
  end

  test "handle incoming favorites - GS, websub" do
    capture_log(fn ->
      incoming = File.read!("test/fixtures/favorite.xml")
      {:ok, [[activity, favorited_activity]]} = OStatus.handle_incoming(incoming)

      assert activity.data["type"] == "Like"
      assert activity.data["actor"] == "https://social.heldscal.la/user/23211"
      assert activity.data["object"] == favorited_activity.data["object"]

      assert activity.data["id"] ==
               "tag:social.heldscal.la,2017-05-05:fave:23211:comment:2061643:2017-05-05T09:12:50+00:00"

      refute activity.local
      assert favorited_activity.data["type"] == "Create"
      assert favorited_activity.data["actor"] == "https://shitposter.club/user/1"

      assert favorited_activity.data["object"] ==
               "tag:shitposter.club,2017-05-05:noticeId=2827873:objectType=comment"

      refute favorited_activity.local
    end)
  end

  test "handle conversation references" do
    incoming = File.read!("test/fixtures/mastodon_conversation.xml")
    {:ok, [activity]} = OStatus.handle_incoming(incoming)

    assert activity.data["context"] ==
             "tag:mastodon.social,2017-08-28:objectId=7876885:objectType=Conversation"
  end

  test "handle incoming favorites with locally available object - GS, websub" do
    note_activity = insert(:note_activity)

    incoming =
      File.read!("test/fixtures/favorite_with_local_note.xml")
      |> String.replace("localid", note_activity.data["object"]["id"])

    {:ok, [[activity, favorited_activity]]} = OStatus.handle_incoming(incoming)

    assert activity.data["type"] == "Like"
    assert activity.data["actor"] == "https://social.heldscal.la/user/23211"
    assert activity.data["object"] == favorited_activity.data["object"]["id"]
    refute activity.local
    assert note_activity.id == favorited_activity.id
    assert favorited_activity.local
  end

  test_with_mock "handle incoming replies, fetching replied-to activities if we don't have them",
                 OStatus,
                 [:passthrough],
                 [] do
    incoming = File.read!("test/fixtures/incoming_note_activity_answer.xml")
    {:ok, [activity]} = OStatus.handle_incoming(incoming)
    object = Object.normalize(activity.data["object"], false)

    assert activity.data["type"] == "Create"
    assert object.data["type"] == "Note"

    assert object.data["inReplyTo"] ==
             "http://pleroma.example.org:4000/objects/55bce8fc-b423-46b1-af71-3759ab4670bc"

    assert "http://pleroma.example.org:4000/users/lain5" in activity.data["to"]

    assert object.data["id"] == "tag:gs.example.org:4040,2017-04-25:noticeId=55:objectType=note"

    assert "https://www.w3.org/ns/activitystreams#Public" in activity.data["to"]

    assert called(OStatus.fetch_activity_from_url(object.data["inReplyTo"], :_))
  end

  test_with_mock "handle incoming replies, not fetching replied-to activities beyond max_replies_depth",
                 OStatus,
                 [:passthrough],
                 [] do
    incoming = File.read!("test/fixtures/incoming_note_activity_answer.xml")

    with_mock Pleroma.Web.Federator,
      max_replies_depth: fn -> 0 end do
      {:ok, [activity]} = OStatus.handle_incoming(incoming)
      object = Object.normalize(activity.data["object"], false)

      refute called(OStatus.fetch_activity_from_url(object.data["inReplyTo"], :_))
    end
  end

  test "handle incoming follows" do
    incoming = File.read!("test/fixtures/follow.xml")
    {:ok, [activity]} = OStatus.handle_incoming(incoming)
    assert activity.data["type"] == "Follow"

    assert activity.data["id"] ==
             "tag:social.heldscal.la,2017-05-07:subscription:23211:person:44803:2017-05-07T09:54:48+00:00"

    assert activity.data["actor"] == "https://social.heldscal.la/user/23211"
    assert activity.data["object"] == "https://pawoo.net/users/pekorino"
    refute activity.local

    follower = User.get_cached_by_ap_id(activity.data["actor"])
    followed = User.get_cached_by_ap_id(activity.data["object"])

    assert User.following?(follower, followed)
  end

  test "handle incoming unfollows with existing follow" do
    incoming_follow = File.read!("test/fixtures/follow.xml")
    {:ok, [_activity]} = OStatus.handle_incoming(incoming_follow)

    incoming = File.read!("test/fixtures/unfollow.xml")
    {:ok, [activity]} = OStatus.handle_incoming(incoming)

    assert activity.data["type"] == "Undo"

    assert activity.data["id"] ==
             "undo:tag:social.heldscal.la,2017-05-07:subscription:23211:person:44803:2017-05-07T09:54:48+00:00"

    assert activity.data["actor"] == "https://social.heldscal.la/user/23211"
    assert is_map(activity.data["object"])
    assert activity.data["object"]["type"] == "Follow"
    assert activity.data["object"]["object"] == "https://pawoo.net/users/pekorino"
    refute activity.local

    follower = User.get_cached_by_ap_id(activity.data["actor"])
    followed = User.get_cached_by_ap_id(activity.data["object"]["object"])

    refute User.following?(follower, followed)
  end

  test "it clears `unreachable` federation status of the sender" do
    incoming_reaction_xml = File.read!("test/fixtures/share-gs.xml")
    doc = XML.parse_document(incoming_reaction_xml)
    actor_uri = XML.string_from_xpath("//author/uri[1]", doc)
    reacted_to_author_uri = XML.string_from_xpath("//author/uri[2]", doc)

    Instances.set_consistently_unreachable(actor_uri)
    Instances.set_consistently_unreachable(reacted_to_author_uri)
    refute Instances.reachable?(actor_uri)
    refute Instances.reachable?(reacted_to_author_uri)

    {:ok, _} = OStatus.handle_incoming(incoming_reaction_xml)
    assert Instances.reachable?(actor_uri)
    refute Instances.reachable?(reacted_to_author_uri)
  end

  describe "new remote user creation" do
    test "returns local users" do
      local_user = insert(:user)
      {:ok, user} = OStatus.find_or_make_user(local_user.ap_id)

      assert user == local_user
    end

    test "tries to use the information in poco fields" do
      uri = "https://social.heldscal.la/user/23211"

      {:ok, user} = OStatus.find_or_make_user(uri)

      user = User.get_cached_by_id(user.id)
      assert user.name == "Constance Variable"
      assert user.nickname == "lambadalambda@social.heldscal.la"
      assert user.local == false
      assert user.info.uri == uri
      assert user.ap_id == uri
      assert user.bio == "Call me Deacon Blues."
      assert user.avatar["type"] == "Image"

      {:ok, user_again} = OStatus.find_or_make_user(uri)

      assert user == user_again
    end

    test "find_or_make_user sets all the nessary input fields" do
      uri = "https://social.heldscal.la/user/23211"
      {:ok, user} = OStatus.find_or_make_user(uri)

      assert user.info ==
               %User.Info{
                 id: user.info.id,
                 ap_enabled: false,
                 background: %{},
                 banner: %{},
                 blocks: [],
                 deactivated: false,
                 default_scope: "public",
                 domain_blocks: [],
                 follower_count: 0,
                 is_admin: false,
                 is_moderator: false,
                 keys: nil,
                 locked: false,
                 no_rich_text: false,
                 note_count: 0,
                 settings: nil,
                 source_data: %{},
                 hub: "https://social.heldscal.la/main/push/hub",
                 magic_key:
                   "RSA.uzg6r1peZU0vXGADWxGJ0PE34WvmhjUmydbX5YYdOiXfODVLwCMi1umGoqUDm-mRu4vNEdFBVJU1CpFA7dKzWgIsqsa501i2XqElmEveXRLvNRWFB6nG03Q5OUY2as8eE54BJm0p20GkMfIJGwP6TSFb-ICp3QjzbatuSPJ6xCE=.AQAB",
                 salmon: "https://social.heldscal.la/main/salmon/user/23211",
                 topic: "https://social.heldscal.la/api/statuses/user_timeline/23211.atom",
                 uri: "https://social.heldscal.la/user/23211"
               }
    end

    test "find_make_or_update_user takes an author element and returns an updated user" do
      uri = "https://social.heldscal.la/user/23211"

      {:ok, user} = OStatus.find_or_make_user(uri)
      old_name = user.name
      old_bio = user.bio
      change = Ecto.Changeset.change(user, %{avatar: nil, bio: nil, name: nil})

      {:ok, user} = Repo.update(change)
      refute user.avatar

      doc = XML.parse_document(File.read!("test/fixtures/23211.atom"))
      [author] = :xmerl_xpath.string('//author[1]', doc)
      {:ok, user} = OStatus.find_make_or_update_user(author)
      assert user.avatar["type"] == "Image"
      assert user.name == old_name
      assert user.bio == old_bio

      {:ok, user_again} = OStatus.find_make_or_update_user(author)
      assert user_again == user
    end
  end

  describe "gathering user info from a user id" do
    test "it returns user info in a hash" do
      user = "shp@social.heldscal.la"

      # TODO: make test local
      {:ok, data} = OStatus.gather_user_info(user)

      expected = %{
        "hub" => "https://social.heldscal.la/main/push/hub",
        "magic_key" =>
          "RSA.wQ3i9UA0qmAxZ0WTIp4a-waZn_17Ez1pEEmqmqoooRsG1_BvpmOvLN0G2tEcWWxl2KOtdQMCiPptmQObeZeuj48mdsDZ4ArQinexY2hCCTcbV8Xpswpkb8K05RcKipdg07pnI7tAgQ0VWSZDImncL6YUGlG5YN8b5TjGOwk2VG8=.AQAB",
        "name" => "shp",
        "nickname" => "shp",
        "salmon" => "https://social.heldscal.la/main/salmon/user/29191",
        "subject" => "acct:shp@social.heldscal.la",
        "topic" => "https://social.heldscal.la/api/statuses/user_timeline/29191.atom",
        "uri" => "https://social.heldscal.la/user/29191",
        "host" => "social.heldscal.la",
        "fqn" => user,
        "bio" => "cofe",
        "avatar" => %{
          "type" => "Image",
          "url" => [
            %{
              "href" => "https://social.heldscal.la/avatar/29191-original-20170421154949.jpeg",
              "mediaType" => "image/jpeg",
              "type" => "Link"
            }
          ]
        },
        "subscribe_address" => "https://social.heldscal.la/main/ostatussub?profile={uri}",
        "ap_id" => nil
      }

      assert data == expected
    end

    test "it works with the uri" do
      user = "https://social.heldscal.la/user/29191"

      # TODO: make test local
      {:ok, data} = OStatus.gather_user_info(user)

      expected = %{
        "hub" => "https://social.heldscal.la/main/push/hub",
        "magic_key" =>
          "RSA.wQ3i9UA0qmAxZ0WTIp4a-waZn_17Ez1pEEmqmqoooRsG1_BvpmOvLN0G2tEcWWxl2KOtdQMCiPptmQObeZeuj48mdsDZ4ArQinexY2hCCTcbV8Xpswpkb8K05RcKipdg07pnI7tAgQ0VWSZDImncL6YUGlG5YN8b5TjGOwk2VG8=.AQAB",
        "name" => "shp",
        "nickname" => "shp",
        "salmon" => "https://social.heldscal.la/main/salmon/user/29191",
        "subject" => "https://social.heldscal.la/user/29191",
        "topic" => "https://social.heldscal.la/api/statuses/user_timeline/29191.atom",
        "uri" => "https://social.heldscal.la/user/29191",
        "host" => "social.heldscal.la",
        "fqn" => user,
        "bio" => "cofe",
        "avatar" => %{
          "type" => "Image",
          "url" => [
            %{
              "href" => "https://social.heldscal.la/avatar/29191-original-20170421154949.jpeg",
              "mediaType" => "image/jpeg",
              "type" => "Link"
            }
          ]
        },
        "subscribe_address" => "https://social.heldscal.la/main/ostatussub?profile={uri}",
        "ap_id" => nil
      }

      assert data == expected
    end
  end

  describe "fetching a status by it's HTML url" do
    test "it builds a missing status from an html url" do
      capture_log(fn ->
        url = "https://shitposter.club/notice/2827873"
        {:ok, [activity]} = OStatus.fetch_activity_from_url(url)

        assert activity.data["actor"] == "https://shitposter.club/user/1"

        assert activity.data["object"] ==
                 "tag:shitposter.club,2017-05-05:noticeId=2827873:objectType=comment"
      end)
    end

    test "it works for atom notes, too" do
      url = "https://social.sakamoto.gq/objects/0ccc1a2c-66b0-4305-b23a-7f7f2b040056"
      {:ok, [activity]} = OStatus.fetch_activity_from_url(url)
      assert activity.data["actor"] == "https://social.sakamoto.gq/users/eal"
      assert activity.data["object"] == url
    end
  end

  test "it doesn't add nil in the to field" do
    incoming = File.read!("test/fixtures/nil_mention_entry.xml")
    {:ok, [activity]} = OStatus.handle_incoming(incoming)

    assert activity.data["to"] == [
             "http://localhost:4001/users/atarifrosch@social.stopwatchingus-heidelberg.de/followers",
             "https://www.w3.org/ns/activitystreams#Public"
           ]
  end

  describe "is_representable?" do
    test "Note objects are representable" do
      note_activity = insert(:note_activity)

      assert OStatus.is_representable?(note_activity)
    end

    test "Article objects are not representable" do
      note_activity = insert(:note_activity)

      note_object = Object.normalize(note_activity.data["object"])

      note_data =
        note_object.data
        |> Map.put("type", "Article")

      Cachex.clear(:object_cache)

      cs = Object.change(note_object, %{data: note_data})
      {:ok, _article_object} = Repo.update(cs)

      # the underlying object is now an Article instead of a note, so this should fail
      refute OStatus.is_representable?(note_activity)
    end
  end
end
