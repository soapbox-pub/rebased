# Pleroma: A lightweight social networking server
# Copyright © 2017-2021 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.ActivityPub.TransmogrifierTest do
  use Oban.Testing, repo: Pleroma.Repo
  use Pleroma.DataCase

  alias Pleroma.Activity
  alias Pleroma.Object
  alias Pleroma.Tests.ObanHelpers
  alias Pleroma.User
  alias Pleroma.Web.ActivityPub.Transmogrifier
  alias Pleroma.Web.ActivityPub.Utils
  alias Pleroma.Web.AdminAPI.AccountView
  alias Pleroma.Web.CommonAPI

  import Mock
  import Pleroma.Factory
  import ExUnit.CaptureLog

  setup_all do
    Tesla.Mock.mock_global(fn env -> apply(HttpRequestMock, :request, [env]) end)
    :ok
  end

  setup do: clear_config([:instance, :max_remote_account_fields])

  describe "handle_incoming" do
    test "it works for incoming unfollows with an existing follow" do
      user = insert(:user)

      follow_data =
        File.read!("test/fixtures/mastodon-follow-activity.json")
        |> Jason.decode!()
        |> Map.put("object", user.ap_id)

      {:ok, %Activity{data: _, local: false}} = Transmogrifier.handle_incoming(follow_data)

      data =
        File.read!("test/fixtures/mastodon-unfollow-activity.json")
        |> Jason.decode!()
        |> Map.put("object", follow_data)

      {:ok, %Activity{data: data, local: false}} = Transmogrifier.handle_incoming(data)

      assert data["type"] == "Undo"
      assert data["object"]["type"] == "Follow"
      assert data["object"]["object"] == user.ap_id
      assert data["actor"] == "http://mastodon.example.org/users/admin"

      refute User.following?(User.get_cached_by_ap_id(data["actor"]), user)
    end

    test "it accepts Flag activities" do
      user = insert(:user)
      other_user = insert(:user)

      {:ok, activity} = CommonAPI.post(user, %{status: "test post"})
      object = Object.normalize(activity, fetch: false)

      note_obj = %{
        "type" => "Note",
        "id" => activity.data["id"],
        "content" => "test post",
        "published" => object.data["published"],
        "actor" => AccountView.render("show.json", %{user: user, skip_visibility_check: true})
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

      {:ok, activity} = CommonAPI.post(user, %{status: "hey", visibility: "private"})

      {:ok, announce_activity} = CommonAPI.repeat(activity.id, user)

      {:ok, modified} = Transmogrifier.prepare_outgoing(announce_activity.data)

      assert modified["object"]["content"] == "hey"
      assert modified["object"]["actor"] == modified["object"]["attributedTo"]
    end

    test "it turns mentions into tags" do
      user = insert(:user)
      other_user = insert(:user)

      {:ok, activity} =
        CommonAPI.post(user, %{status: "hey, @#{other_user.nickname}, how are ya? #2hu"})

      with_mock Pleroma.Notification,
        get_notified_from_activity: fn _, _ -> [] end do
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

        refute called(Pleroma.Notification.get_notified_from_activity(:_, :_))
        assert Enum.member?(object["tag"], expected_tag)
        assert Enum.member?(object["tag"], expected_mention)
      end
    end

    test "it adds the json-ld context and the conversation property" do
      user = insert(:user)

      {:ok, activity} = CommonAPI.post(user, %{status: "hey"})
      {:ok, modified} = Transmogrifier.prepare_outgoing(activity.data)

      assert modified["@context"] == Utils.make_json_ld_header()["@context"]

      assert modified["object"]["conversation"] == modified["context"]
    end

    test "it sets the 'attributedTo' property to the actor of the object if it doesn't have one" do
      user = insert(:user)

      {:ok, activity} = CommonAPI.post(user, %{status: "hey"})
      {:ok, modified} = Transmogrifier.prepare_outgoing(activity.data)

      assert modified["object"]["actor"] == modified["object"]["attributedTo"]
    end

    test "it strips internal hashtag data" do
      user = insert(:user)

      {:ok, activity} = CommonAPI.post(user, %{status: "#2hu"})

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

      {:ok, activity} =
        CommonAPI.post(user, %{
          status: "#2hu :firefox:",
          generator: %{type: "Application", name: "TestClient", url: "https://pleroma.social"}
        })

      # Ensure injected application data made it into the activity
      # as we don't have a Token to derive it from, otherwise it will
      # be nil and the test will pass
      assert %{
               type: "Application",
               name: "TestClient",
               url: "https://pleroma.social"
             } == activity.object.data["generator"]

      {:ok, modified} = Transmogrifier.prepare_outgoing(activity.data)

      assert length(modified["object"]["tag"]) == 2

      assert is_nil(modified["object"]["emoji"])
      assert is_nil(modified["object"]["like_count"])
      assert is_nil(modified["object"]["announcements"])
      assert is_nil(modified["object"]["announcement_count"])
      assert is_nil(modified["object"]["context_id"])
      assert is_nil(modified["object"]["generator"])
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

      {:ok, activity} = CommonAPI.post(user, %{status: "2hu :moominmamma:"})

      {:ok, modified} = Transmogrifier.prepare_outgoing(activity.data)

      assert modified["directMessage"] == false

      {:ok, activity} = CommonAPI.post(user, %{status: "@#{other_user.nickname} :moominmamma:"})

      {:ok, modified} = Transmogrifier.prepare_outgoing(activity.data)

      assert modified["directMessage"] == false

      {:ok, activity} =
        CommonAPI.post(user, %{
          status: "@#{other_user.nickname} :moominmamma:",
          visibility: "direct"
        })

      {:ok, modified} = Transmogrifier.prepare_outgoing(activity.data)

      assert modified["directMessage"] == true
    end

    test "it strips BCC field" do
      user = insert(:user)
      {:ok, list} = Pleroma.List.create("foo", user)

      {:ok, activity} = CommonAPI.post(user, %{status: "foobar", visibility: "list:#{list.id}"})

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

    test "custom emoji urls are URI encoded" do
      # :dinosaur: filename has a space -> dino walking.gif
      user = insert(:user)

      {:ok, activity} = CommonAPI.post(user, %{status: "everybody do the dinosaur :dinosaur:"})

      {:ok, prepared} = Transmogrifier.prepare_outgoing(activity.data)

      assert length(prepared["object"]["tag"]) == 1

      url = prepared["object"]["tag"] |> List.first() |> Map.get("icon") |> Map.get("url")

      assert url == "http://localhost:4001/emoji/dino%20walking.gif"
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
      Pleroma.FollowingRelationship.follow(user_two, user, :follow_accept)

      {:ok, activity} = CommonAPI.post(user, %{status: "test"})
      {:ok, unrelated_activity} = CommonAPI.post(user_two, %{status: "test"})
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
               {:error, _} = Transmogrifier.handle_incoming(data)
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
               {:error, _} = Transmogrifier.handle_incoming(data)
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
               {:error, _} = Transmogrifier.handle_incoming(data)
             end) =~ "Object containment failed"
    end
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

      fixed_object = Transmogrifier.fix_explicit_addressing(object, user.follower_address)
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

      fixed_object = Transmogrifier.fix_explicit_addressing(object, user.follower_address)
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

      fixed_object = Transmogrifier.fix_explicit_addressing(object, user.follower_address)

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

    test "returns non-modified object" do
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
               Transmogrifier.get_obj_helper(
                 "https://mstdn.io/users/mayuutann/statuses/99568293732299394"
               )
    end
  end
end
