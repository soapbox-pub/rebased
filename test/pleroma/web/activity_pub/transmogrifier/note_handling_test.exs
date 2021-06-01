# Pleroma: A lightweight social networking server
# Copyright © 2017-2021 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.ActivityPub.Transmogrifier.NoteHandlingTest do
  use Oban.Testing, repo: Pleroma.Repo
  use Pleroma.DataCase

  alias Pleroma.Activity
  alias Pleroma.Object
  alias Pleroma.User
  alias Pleroma.Web.ActivityPub.Transmogrifier
  alias Pleroma.Web.ActivityPub.Utils
  alias Pleroma.Web.CommonAPI

  import Mock
  import Pleroma.Factory

  setup_all do
    Tesla.Mock.mock_global(fn env -> apply(HttpRequestMock, :request, [env]) end)
    :ok
  end

  setup do: clear_config([:instance, :max_remote_account_fields])

  describe "handle_incoming" do
    test "it works for incoming notices with tag not being an array (kroeg)" do
      data = File.read!("test/fixtures/kroeg-array-less-emoji.json") |> Jason.decode!()

      {:ok, %Activity{data: data, local: false}} = Transmogrifier.handle_incoming(data)
      object = Object.normalize(data["object"], fetch: false)

      assert object.data["emoji"] == %{
               "icon_e_smile" => "https://puckipedia.com/forum/images/smilies/icon_e_smile.png"
             }

      data = File.read!("test/fixtures/kroeg-array-less-hashtag.json") |> Jason.decode!()

      {:ok, %Activity{data: data, local: false}} = Transmogrifier.handle_incoming(data)
      object = Object.normalize(data["object"], fetch: false)

      assert "test" in Object.tags(object)
      assert Object.hashtags(object) == ["test"]
    end

    test "it ignores an incoming notice if we already have it" do
      activity = insert(:note_activity)

      data =
        File.read!("test/fixtures/mastodon-post-activity.json")
        |> Jason.decode!()
        |> Map.put("object", Object.normalize(activity, fetch: false).data)

      {:ok, returned_activity} = Transmogrifier.handle_incoming(data)

      assert activity == returned_activity
    end

    @tag capture_log: true
    test "it fetches reply-to activities if we don't have them" do
      data =
        File.read!("test/fixtures/mastodon-post-activity.json")
        |> Jason.decode!()

      object =
        data["object"]
        |> Map.put("inReplyTo", "https://mstdn.io/users/mayuutann/statuses/99568293732299394")

      data = Map.put(data, "object", object)
      {:ok, returned_activity} = Transmogrifier.handle_incoming(data)
      returned_object = Object.normalize(returned_activity, fetch: false)

      assert %Activity{} =
               Activity.get_create_by_object_ap_id(
                 "https://mstdn.io/users/mayuutann/statuses/99568293732299394"
               )

      assert returned_object.data["inReplyTo"] ==
               "https://mstdn.io/users/mayuutann/statuses/99568293732299394"
    end

    test "it does not fetch reply-to activities beyond max replies depth limit" do
      data =
        File.read!("test/fixtures/mastodon-post-activity.json")
        |> Jason.decode!()

      object =
        data["object"]
        |> Map.put("inReplyTo", "https://shitposter.club/notice/2827873")

      data = Map.put(data, "object", object)

      with_mock Pleroma.Web.Federator,
        allowed_thread_distance?: fn _ -> false end do
        {:ok, returned_activity} = Transmogrifier.handle_incoming(data)

        returned_object = Object.normalize(returned_activity, fetch: false)

        refute Activity.get_create_by_object_ap_id(
                 "tag:shitposter.club,2017-05-05:noticeId=2827873:objectType=comment"
               )

        assert returned_object.data["inReplyTo"] == "https://shitposter.club/notice/2827873"
      end
    end

    test "it does not crash if the object in inReplyTo can't be fetched" do
      data =
        File.read!("test/fixtures/mastodon-post-activity.json")
        |> Jason.decode!()

      object =
        data["object"]
        |> Map.put("inReplyTo", "https://404.site/whatever")

      data =
        data
        |> Map.put("object", object)

      assert {:ok, _returned_activity} = Transmogrifier.handle_incoming(data)
    end

    test "it does not work for deactivated users" do
      data = File.read!("test/fixtures/mastodon-post-activity.json") |> Jason.decode!()

      insert(:user, ap_id: data["actor"], is_active: false)

      assert {:error, _} = Transmogrifier.handle_incoming(data)
    end

    test "it works for incoming notices" do
      data = File.read!("test/fixtures/mastodon-post-activity.json") |> Jason.decode!()

      {:ok, %Activity{data: data, local: false}} = Transmogrifier.handle_incoming(data)

      assert data["id"] ==
               "http://mastodon.example.org/users/admin/statuses/99512778738411822/activity"

      assert data["context"] ==
               "tag:mastodon.example.org,2018-02-12:objectId=20:objectType=Conversation"

      assert data["to"] == ["https://www.w3.org/ns/activitystreams#Public"]

      assert data["cc"] == [
               "http://localtesting.pleroma.lol/users/lain",
               "http://mastodon.example.org/users/admin/followers"
             ]

      assert data["actor"] == "http://mastodon.example.org/users/admin"

      object_data = Object.normalize(data["object"], fetch: false).data

      assert object_data["id"] ==
               "http://mastodon.example.org/users/admin/statuses/99512778738411822"

      assert object_data["to"] == ["https://www.w3.org/ns/activitystreams#Public"]

      assert object_data["cc"] == [
               "http://localtesting.pleroma.lol/users/lain",
               "http://mastodon.example.org/users/admin/followers"
             ]

      assert object_data["actor"] == "http://mastodon.example.org/users/admin"
      assert object_data["attributedTo"] == "http://mastodon.example.org/users/admin"

      assert object_data["context"] ==
               "tag:mastodon.example.org,2018-02-12:objectId=20:objectType=Conversation"

      assert object_data["sensitive"] == true

      user = User.get_cached_by_ap_id(object_data["actor"])

      assert user.note_count == 1
    end

    test "it works for incoming notices without the sensitive property but an nsfw hashtag" do
      data = File.read!("test/fixtures/mastodon-post-activity-nsfw.json") |> Jason.decode!()

      {:ok, %Activity{data: data, local: false}} = Transmogrifier.handle_incoming(data)

      object_data = Object.normalize(data["object"], fetch: false).data

      assert object_data["sensitive"] == true
    end

    test "it works for incoming notices with hashtags" do
      data = File.read!("test/fixtures/mastodon-post-activity-hashtag.json") |> Jason.decode!()

      {:ok, %Activity{data: data, local: false}} = Transmogrifier.handle_incoming(data)
      object = Object.normalize(data["object"], fetch: false)

      assert match?(
               %{
                 "href" => "http://localtesting.pleroma.lol/users/lain",
                 "name" => "@lain@localtesting.pleroma.lol",
                 "type" => "Mention"
               },
               Enum.at(object.data["tag"], 0)
             )

      assert match?(
               %{
                 "href" => "http://mastodon.example.org/tags/moo",
                 "name" => "#moo",
                 "type" => "Hashtag"
               },
               Enum.at(object.data["tag"], 1)
             )

      assert "moo" == Enum.at(object.data["tag"], 2)
    end

    test "it works for incoming notices with contentMap" do
      data = File.read!("test/fixtures/mastodon-post-activity-contentmap.json") |> Jason.decode!()

      {:ok, %Activity{data: data, local: false}} = Transmogrifier.handle_incoming(data)
      object = Object.normalize(data["object"], fetch: false)

      assert object.data["content"] ==
               "<p><span class=\"h-card\"><a href=\"http://localtesting.pleroma.lol/users/lain\" class=\"u-url mention\">@<span>lain</span></a></span></p>"
    end

    test "it works for incoming notices with to/cc not being an array (kroeg)" do
      data = File.read!("test/fixtures/kroeg-post-activity.json") |> Jason.decode!()

      {:ok, %Activity{data: data, local: false}} = Transmogrifier.handle_incoming(data)
      object = Object.normalize(data["object"], fetch: false)

      assert object.data["content"] ==
               "<p>henlo from my Psion netBook</p><p>message sent from my Psion netBook</p>"
    end

    test "it ensures that as:Public activities make it to their followers collection" do
      user = insert(:user)

      data =
        File.read!("test/fixtures/mastodon-post-activity.json")
        |> Jason.decode!()
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
        |> Jason.decode!()
        |> Map.put("actor", user.ap_id)
        |> Map.put("cc", nil)

      object =
        data["object"]
        |> Map.put("attributedTo", user.ap_id)
        |> Map.put("cc", nil)
        |> Map.put("id", user.ap_id <> "/activities/12345678")

      data = Map.put(data, "object", object)

      {:ok, %Activity{data: data, local: false}} = Transmogrifier.handle_incoming(data)

      refute is_nil(data["cc"])
    end

    test "it strips internal likes" do
      data =
        File.read!("test/fixtures/mastodon-post-activity.json")
        |> Jason.decode!()

      likes = %{
        "first" =>
          "http://mastodon.example.org/objects/dbdbc507-52c8-490d-9b7c-1e1d52e5c132/likes?page=1",
        "id" => "http://mastodon.example.org/objects/dbdbc507-52c8-490d-9b7c-1e1d52e5c132/likes",
        "totalItems" => 3,
        "type" => "OrderedCollection"
      }

      object = Map.put(data["object"], "likes", likes)
      data = Map.put(data, "object", object)

      {:ok, %Activity{} = activity} = Transmogrifier.handle_incoming(data)

      object = Object.normalize(activity)

      assert object.data["likes"] == []
    end

    test "it strips internal reactions" do
      user = insert(:user)
      {:ok, activity} = CommonAPI.post(user, %{status: "#cofe"})
      {:ok, _} = CommonAPI.react_with_emoji(activity.id, user, "📢")

      %{object: object} = Activity.get_by_id_with_object(activity.id)
      assert Map.has_key?(object.data, "reactions")
      assert Map.has_key?(object.data, "reaction_count")

      object_data = Transmogrifier.strip_internal_fields(object.data)
      refute Map.has_key?(object_data, "reactions")
      refute Map.has_key?(object_data, "reaction_count")
    end

    test "it correctly processes messages with non-array to field" do
      data =
        File.read!("test/fixtures/mastodon-post-activity.json")
        |> Poison.decode!()
        |> Map.put("to", "https://www.w3.org/ns/activitystreams#Public")
        |> put_in(["object", "to"], "https://www.w3.org/ns/activitystreams#Public")

      assert {:ok, activity} = Transmogrifier.handle_incoming(data)

      assert [
               "http://localtesting.pleroma.lol/users/lain",
               "http://mastodon.example.org/users/admin/followers"
             ] == activity.data["cc"]

      assert ["https://www.w3.org/ns/activitystreams#Public"] == activity.data["to"]
    end

    test "it correctly processes messages with non-array cc field" do
      data =
        File.read!("test/fixtures/mastodon-post-activity.json")
        |> Poison.decode!()
        |> Map.put("cc", "http://mastodon.example.org/users/admin/followers")
        |> put_in(["object", "cc"], "http://mastodon.example.org/users/admin/followers")

      assert {:ok, activity} = Transmogrifier.handle_incoming(data)

      assert ["http://mastodon.example.org/users/admin/followers"] == activity.data["cc"]
      assert ["https://www.w3.org/ns/activitystreams#Public"] == activity.data["to"]
    end

    test "it correctly processes messages with weirdness in address fields" do
      data =
        File.read!("test/fixtures/mastodon-post-activity.json")
        |> Poison.decode!()
        |> Map.put("cc", ["http://mastodon.example.org/users/admin/followers", ["¿"]])
        |> put_in(["object", "cc"], ["http://mastodon.example.org/users/admin/followers", ["¿"]])

      assert {:ok, activity} = Transmogrifier.handle_incoming(data)

      assert ["http://mastodon.example.org/users/admin/followers"] == activity.data["cc"]
      assert ["https://www.w3.org/ns/activitystreams#Public"] == activity.data["to"]
    end
  end

  describe "`handle_incoming/2`, Mastodon format `replies` handling" do
    setup do: clear_config([:activitypub, :note_replies_output_limit], 5)
    setup do: clear_config([:instance, :federation_incoming_replies_max_depth])

    setup do
      data =
        "test/fixtures/mastodon-post-activity.json"
        |> File.read!()
        |> Jason.decode!()

      items = get_in(data, ["object", "replies", "first", "items"])
      assert length(items) > 0

      %{data: data, items: items}
    end

    test "schedules background fetching of `replies` items if max thread depth limit allows", %{
      data: data,
      items: items
    } do
      clear_config([:instance, :federation_incoming_replies_max_depth], 10)

      {:ok, activity} = Transmogrifier.handle_incoming(data)

      object = Object.normalize(activity.data["object"])

      assert object.data["replies"] == items

      for id <- items do
        job_args = %{"op" => "fetch_remote", "id" => id, "depth" => 1}
        assert_enqueued(worker: Pleroma.Workers.RemoteFetcherWorker, args: job_args)
      end
    end

    test "does NOT schedule background fetching of `replies` beyond max thread depth limit allows",
         %{data: data} do
      clear_config([:instance, :federation_incoming_replies_max_depth], 0)

      {:ok, _activity} = Transmogrifier.handle_incoming(data)

      assert all_enqueued(worker: Pleroma.Workers.RemoteFetcherWorker) == []
    end
  end

  describe "`handle_incoming/2`, Pleroma format `replies` handling" do
    setup do: clear_config([:activitypub, :note_replies_output_limit], 5)
    setup do: clear_config([:instance, :federation_incoming_replies_max_depth])

    setup do
      replies = %{
        "type" => "Collection",
        "items" => [Utils.generate_object_id(), Utils.generate_object_id()]
      }

      activity =
        File.read!("test/fixtures/mastodon-post-activity.json")
        |> Poison.decode!()
        |> Kernel.put_in(["object", "replies"], replies)

      %{activity: activity}
    end

    test "schedules background fetching of `replies` items if max thread depth limit allows", %{
      activity: activity
    } do
      clear_config([:instance, :federation_incoming_replies_max_depth], 1)

      assert {:ok, %Activity{data: data, local: false}} = Transmogrifier.handle_incoming(activity)
      object = Object.normalize(data["object"])

      for id <- object.data["replies"] do
        job_args = %{"op" => "fetch_remote", "id" => id, "depth" => 1}
        assert_enqueued(worker: Pleroma.Workers.RemoteFetcherWorker, args: job_args)
      end
    end

    test "does NOT schedule background fetching of `replies` beyond max thread depth limit allows",
         %{activity: activity} do
      clear_config([:instance, :federation_incoming_replies_max_depth], 0)

      {:ok, _activity} = Transmogrifier.handle_incoming(activity)

      assert all_enqueued(worker: Pleroma.Workers.RemoteFetcherWorker) == []
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
          "id" => Utils.generate_object_id(),
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
          "id" => Utils.generate_object_id(),
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

  describe "fix_in_reply_to/2" do
    setup do: clear_config([:instance, :federation_incoming_replies_max_depth])

    setup do
      data = Jason.decode!(File.read!("test/fixtures/mastodon-post-activity.json"))
      [data: data]
    end

    test "returns not modified object when hasn't containts inReplyTo field", %{data: data} do
      assert Transmogrifier.fix_in_reply_to(data) == data
    end

    test "returns object with inReplyTo when denied incoming reply", %{data: data} do
      clear_config([:instance, :federation_incoming_replies_max_depth], 0)

      object_with_reply =
        Map.put(data["object"], "inReplyTo", "https://shitposter.club/notice/2827873")

      modified_object = Transmogrifier.fix_in_reply_to(object_with_reply)
      assert modified_object["inReplyTo"] == "https://shitposter.club/notice/2827873"

      object_with_reply =
        Map.put(data["object"], "inReplyTo", %{"id" => "https://shitposter.club/notice/2827873"})

      modified_object = Transmogrifier.fix_in_reply_to(object_with_reply)
      assert modified_object["inReplyTo"] == %{"id" => "https://shitposter.club/notice/2827873"}

      object_with_reply =
        Map.put(data["object"], "inReplyTo", ["https://shitposter.club/notice/2827873"])

      modified_object = Transmogrifier.fix_in_reply_to(object_with_reply)
      assert modified_object["inReplyTo"] == ["https://shitposter.club/notice/2827873"]

      object_with_reply = Map.put(data["object"], "inReplyTo", [])
      modified_object = Transmogrifier.fix_in_reply_to(object_with_reply)
      assert modified_object["inReplyTo"] == []
    end

    @tag capture_log: true
    test "returns modified object when allowed incoming reply", %{data: data} do
      object_with_reply =
        Map.put(
          data["object"],
          "inReplyTo",
          "https://mstdn.io/users/mayuutann/statuses/99568293732299394"
        )

      clear_config([:instance, :federation_incoming_replies_max_depth], 5)
      modified_object = Transmogrifier.fix_in_reply_to(object_with_reply)

      assert modified_object["inReplyTo"] ==
               "https://mstdn.io/users/mayuutann/statuses/99568293732299394"

      assert modified_object["context"] ==
               "tag:shitposter.club,2018-02-22:objectType=thread:nonce=e5a7c72d60a9c0e4"
    end
  end

  describe "fix_attachments/1" do
    test "returns not modified object" do
      data = Jason.decode!(File.read!("test/fixtures/mastodon-post-activity.json"))
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
                   "type" => "Document",
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
                   "type" => "Document",
                   "url" => [
                     %{
                       "href" => "https://pe.er/stat-480.mp4",
                       "mediaType" => "video/mp4",
                       "type" => "Link"
                     }
                   ]
                 },
                 %{
                   "mediaType" => "video/mp4",
                   "type" => "Document",
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
      data = Jason.decode!(File.read!("test/fixtures/mastodon-post-activity.json"))
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

  describe "set_replies/1" do
    setup do: clear_config([:activitypub, :note_replies_output_limit], 2)

    test "returns unmodified object if activity doesn't have self-replies" do
      data = Jason.decode!(File.read!("test/fixtures/mastodon-post-activity.json"))
      assert Transmogrifier.set_replies(data) == data
    end

    test "sets `replies` collection with a limited number of self-replies" do
      [user, another_user] = insert_list(2, :user)

      {:ok, %{id: id1} = activity} = CommonAPI.post(user, %{status: "1"})

      {:ok, %{id: id2} = self_reply1} =
        CommonAPI.post(user, %{status: "self-reply 1", in_reply_to_status_id: id1})

      {:ok, self_reply2} =
        CommonAPI.post(user, %{status: "self-reply 2", in_reply_to_status_id: id1})

      # Assuming to _not_ be present in `replies` due to :note_replies_output_limit is set to 2
      {:ok, _} = CommonAPI.post(user, %{status: "self-reply 3", in_reply_to_status_id: id1})

      {:ok, _} =
        CommonAPI.post(user, %{
          status: "self-reply to self-reply",
          in_reply_to_status_id: id2
        })

      {:ok, _} =
        CommonAPI.post(another_user, %{
          status: "another user's reply",
          in_reply_to_status_id: id1
        })

      object = Object.normalize(activity, fetch: false)
      replies_uris = Enum.map([self_reply1, self_reply2], fn a -> a.object.data["id"] end)

      assert %{"type" => "Collection", "items" => ^replies_uris} =
               Transmogrifier.set_replies(object.data)["replies"]
    end
  end

  test "take_emoji_tags/1" do
    user = insert(:user, %{emoji: %{"firefox" => "https://example.org/firefox.png"}})

    assert Transmogrifier.take_emoji_tags(user) == [
             %{
               "icon" => %{"type" => "Image", "url" => "https://example.org/firefox.png"},
               "id" => "https://example.org/firefox.png",
               "name" => ":firefox:",
               "type" => "Emoji",
               "updated" => "1970-01-01T00:00:00Z"
             }
           ]
  end
end
