# Pleroma: A lightweight social networking server
# Copyright © 2017-2020 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.ActivityPub.ActivityPubControllerTest do
  use Pleroma.Web.ConnCase
  use Oban.Testing, repo: Pleroma.Repo

  import Pleroma.Factory
  alias Pleroma.Activity
  alias Pleroma.Delivery
  alias Pleroma.Instances
  alias Pleroma.Object
  alias Pleroma.Tests.ObanHelpers
  alias Pleroma.User
  alias Pleroma.Web.ActivityPub.ObjectView
  alias Pleroma.Web.ActivityPub.Relay
  alias Pleroma.Web.ActivityPub.UserView
  alias Pleroma.Web.ActivityPub.Utils
  alias Pleroma.Web.CommonAPI
  alias Pleroma.Workers.ReceiverWorker

  setup_all do
    Tesla.Mock.mock_global(fn env -> apply(HttpRequestMock, :request, [env]) end)
    :ok
  end

  clear_config_all([:instance, :federating],
    do: Pleroma.Config.put([:instance, :federating], true)
  )

  describe "/relay" do
    clear_config([:instance, :allow_relay])

    test "with the relay active, it returns the relay user", %{conn: conn} do
      res =
        conn
        |> get(activity_pub_path(conn, :relay))
        |> json_response(200)

      assert res["id"] =~ "/relay"
    end

    test "with the relay disabled, it returns 404", %{conn: conn} do
      Pleroma.Config.put([:instance, :allow_relay], false)

      conn
      |> get(activity_pub_path(conn, :relay))
      |> json_response(404)
      |> assert
    end
  end

  describe "/internal/fetch" do
    test "it returns the internal fetch user", %{conn: conn} do
      res =
        conn
        |> get(activity_pub_path(conn, :internal_fetch))
        |> json_response(200)

      assert res["id"] =~ "/fetch"
    end
  end

  describe "/users/:nickname" do
    test "it returns a json representation of the user with accept application/json", %{
      conn: conn
    } do
      user = insert(:user)

      conn =
        conn
        |> put_req_header("accept", "application/json")
        |> get("/users/#{user.nickname}")

      user = User.get_cached_by_id(user.id)

      assert json_response(conn, 200) == UserView.render("user.json", %{user: user})
    end

    test "it returns a json representation of the user with accept application/activity+json", %{
      conn: conn
    } do
      user = insert(:user)

      conn =
        conn
        |> put_req_header("accept", "application/activity+json")
        |> get("/users/#{user.nickname}")

      user = User.get_cached_by_id(user.id)

      assert json_response(conn, 200) == UserView.render("user.json", %{user: user})
    end

    test "it returns a json representation of the user with accept application/ld+json", %{
      conn: conn
    } do
      user = insert(:user)

      conn =
        conn
        |> put_req_header(
          "accept",
          "application/ld+json; profile=\"https://www.w3.org/ns/activitystreams\""
        )
        |> get("/users/#{user.nickname}")

      user = User.get_cached_by_id(user.id)

      assert json_response(conn, 200) == UserView.render("user.json", %{user: user})
    end

    test "it returns 404 for remote users", %{
      conn: conn
    } do
      user = insert(:user, local: false, nickname: "remoteuser@example.com")

      conn =
        conn
        |> put_req_header("accept", "application/json")
        |> get("/users/#{user.nickname}.json")

      assert json_response(conn, 404)
    end
  end

  describe "/object/:uuid" do
    test "it returns a json representation of the object with accept application/json", %{
      conn: conn
    } do
      note = insert(:note)
      uuid = String.split(note.data["id"], "/") |> List.last()

      conn =
        conn
        |> put_req_header("accept", "application/json")
        |> get("/objects/#{uuid}")

      assert json_response(conn, 200) == ObjectView.render("object.json", %{object: note})
    end

    test "it returns a json representation of the object with accept application/activity+json",
         %{conn: conn} do
      note = insert(:note)
      uuid = String.split(note.data["id"], "/") |> List.last()

      conn =
        conn
        |> put_req_header("accept", "application/activity+json")
        |> get("/objects/#{uuid}")

      assert json_response(conn, 200) == ObjectView.render("object.json", %{object: note})
    end

    test "it returns a json representation of the object with accept application/ld+json", %{
      conn: conn
    } do
      note = insert(:note)
      uuid = String.split(note.data["id"], "/") |> List.last()

      conn =
        conn
        |> put_req_header(
          "accept",
          "application/ld+json; profile=\"https://www.w3.org/ns/activitystreams\""
        )
        |> get("/objects/#{uuid}")

      assert json_response(conn, 200) == ObjectView.render("object.json", %{object: note})
    end

    test "it returns 404 for non-public messages", %{conn: conn} do
      note = insert(:direct_note)
      uuid = String.split(note.data["id"], "/") |> List.last()

      conn =
        conn
        |> put_req_header("accept", "application/activity+json")
        |> get("/objects/#{uuid}")

      assert json_response(conn, 404)
    end

    test "it returns 404 for tombstone objects", %{conn: conn} do
      tombstone = insert(:tombstone)
      uuid = String.split(tombstone.data["id"], "/") |> List.last()

      conn =
        conn
        |> put_req_header("accept", "application/activity+json")
        |> get("/objects/#{uuid}")

      assert json_response(conn, 404)
    end

    test "it caches a response", %{conn: conn} do
      note = insert(:note)
      uuid = String.split(note.data["id"], "/") |> List.last()

      conn1 =
        conn
        |> put_req_header("accept", "application/activity+json")
        |> get("/objects/#{uuid}")

      assert json_response(conn1, :ok)
      assert Enum.any?(conn1.resp_headers, &(&1 == {"x-cache", "MISS from Pleroma"}))

      conn2 =
        conn
        |> put_req_header("accept", "application/activity+json")
        |> get("/objects/#{uuid}")

      assert json_response(conn1, :ok) == json_response(conn2, :ok)
      assert Enum.any?(conn2.resp_headers, &(&1 == {"x-cache", "HIT from Pleroma"}))
    end

    test "cached purged after object deletion", %{conn: conn} do
      note = insert(:note)
      uuid = String.split(note.data["id"], "/") |> List.last()

      conn1 =
        conn
        |> put_req_header("accept", "application/activity+json")
        |> get("/objects/#{uuid}")

      assert json_response(conn1, :ok)
      assert Enum.any?(conn1.resp_headers, &(&1 == {"x-cache", "MISS from Pleroma"}))

      Object.delete(note)

      conn2 =
        conn
        |> put_req_header("accept", "application/activity+json")
        |> get("/objects/#{uuid}")

      assert "Not found" == json_response(conn2, :not_found)
    end
  end

  describe "/activities/:uuid" do
    test "it returns a json representation of the activity", %{conn: conn} do
      activity = insert(:note_activity)
      uuid = String.split(activity.data["id"], "/") |> List.last()

      conn =
        conn
        |> put_req_header("accept", "application/activity+json")
        |> get("/activities/#{uuid}")

      assert json_response(conn, 200) == ObjectView.render("object.json", %{object: activity})
    end

    test "it returns 404 for non-public activities", %{conn: conn} do
      activity = insert(:direct_note_activity)
      uuid = String.split(activity.data["id"], "/") |> List.last()

      conn =
        conn
        |> put_req_header("accept", "application/activity+json")
        |> get("/activities/#{uuid}")

      assert json_response(conn, 404)
    end

    test "it caches a response", %{conn: conn} do
      activity = insert(:note_activity)
      uuid = String.split(activity.data["id"], "/") |> List.last()

      conn1 =
        conn
        |> put_req_header("accept", "application/activity+json")
        |> get("/activities/#{uuid}")

      assert json_response(conn1, :ok)
      assert Enum.any?(conn1.resp_headers, &(&1 == {"x-cache", "MISS from Pleroma"}))

      conn2 =
        conn
        |> put_req_header("accept", "application/activity+json")
        |> get("/activities/#{uuid}")

      assert json_response(conn1, :ok) == json_response(conn2, :ok)
      assert Enum.any?(conn2.resp_headers, &(&1 == {"x-cache", "HIT from Pleroma"}))
    end

    test "cached purged after activity deletion", %{conn: conn} do
      user = insert(:user)
      {:ok, activity} = CommonAPI.post(user, %{"status" => "cofe"})

      uuid = String.split(activity.data["id"], "/") |> List.last()

      conn1 =
        conn
        |> put_req_header("accept", "application/activity+json")
        |> get("/activities/#{uuid}")

      assert json_response(conn1, :ok)
      assert Enum.any?(conn1.resp_headers, &(&1 == {"x-cache", "MISS from Pleroma"}))

      Activity.delete_all_by_object_ap_id(activity.object.data["id"])

      conn2 =
        conn
        |> put_req_header("accept", "application/activity+json")
        |> get("/activities/#{uuid}")

      assert "Not found" == json_response(conn2, :not_found)
    end
  end

  describe "/inbox" do
    test "it inserts an incoming activity into the database", %{conn: conn} do
      data = File.read!("test/fixtures/mastodon-post-activity.json") |> Poison.decode!()

      conn =
        conn
        |> assign(:valid_signature, true)
        |> put_req_header("content-type", "application/activity+json")
        |> post("/inbox", data)

      assert "ok" == json_response(conn, 200)

      ObanHelpers.perform(all_enqueued(worker: ReceiverWorker))
      assert Activity.get_by_ap_id(data["id"])
    end

    test "it clears `unreachable` federation status of the sender", %{conn: conn} do
      data = File.read!("test/fixtures/mastodon-post-activity.json") |> Poison.decode!()

      sender_url = data["actor"]
      Instances.set_consistently_unreachable(sender_url)
      refute Instances.reachable?(sender_url)

      conn =
        conn
        |> assign(:valid_signature, true)
        |> put_req_header("content-type", "application/activity+json")
        |> post("/inbox", data)

      assert "ok" == json_response(conn, 200)
      assert Instances.reachable?(sender_url)
    end
  end

  describe "/users/:nickname/inbox" do
    setup do
      data =
        File.read!("test/fixtures/mastodon-post-activity.json")
        |> Poison.decode!()

      [data: data]
    end

    test "it inserts an incoming activity into the database", %{conn: conn, data: data} do
      user = insert(:user)
      data = Map.put(data, "bcc", [user.ap_id])

      conn =
        conn
        |> assign(:valid_signature, true)
        |> put_req_header("content-type", "application/activity+json")
        |> post("/users/#{user.nickname}/inbox", data)

      assert "ok" == json_response(conn, 200)
      ObanHelpers.perform(all_enqueued(worker: ReceiverWorker))
      assert Activity.get_by_ap_id(data["id"])
    end

    test "it accepts messages with to as string instead of array", %{conn: conn, data: data} do
      user = insert(:user)

      data =
        Map.put(data, "to", user.ap_id)
        |> Map.delete("cc")

      conn =
        conn
        |> assign(:valid_signature, true)
        |> put_req_header("content-type", "application/activity+json")
        |> post("/users/#{user.nickname}/inbox", data)

      assert "ok" == json_response(conn, 200)
      ObanHelpers.perform(all_enqueued(worker: ReceiverWorker))
      assert Activity.get_by_ap_id(data["id"])
    end

    test "it accepts messages with cc as string instead of array", %{conn: conn, data: data} do
      user = insert(:user)

      data =
        Map.put(data, "cc", user.ap_id)
        |> Map.delete("to")

      conn =
        conn
        |> assign(:valid_signature, true)
        |> put_req_header("content-type", "application/activity+json")
        |> post("/users/#{user.nickname}/inbox", data)

      assert "ok" == json_response(conn, 200)
      ObanHelpers.perform(all_enqueued(worker: ReceiverWorker))
      %Activity{} = activity = Activity.get_by_ap_id(data["id"])
      assert user.ap_id in activity.recipients
    end

    test "it accepts messages with bcc as string instead of array", %{conn: conn, data: data} do
      user = insert(:user)

      data =
        Map.put(data, "bcc", user.ap_id)
        |> Map.delete("to")
        |> Map.delete("cc")

      conn =
        conn
        |> assign(:valid_signature, true)
        |> put_req_header("content-type", "application/activity+json")
        |> post("/users/#{user.nickname}/inbox", data)

      assert "ok" == json_response(conn, 200)
      ObanHelpers.perform(all_enqueued(worker: ReceiverWorker))
      assert Activity.get_by_ap_id(data["id"])
    end

    test "it accepts announces with to as string instead of array", %{conn: conn} do
      user = insert(:user)

      data = %{
        "@context" => "https://www.w3.org/ns/activitystreams",
        "actor" => "http://mastodon.example.org/users/admin",
        "id" => "http://mastodon.example.org/users/admin/statuses/19512778738411822/activity",
        "object" => "https://mastodon.social/users/emelie/statuses/101849165031453009",
        "to" => "https://www.w3.org/ns/activitystreams#Public",
        "cc" => [user.ap_id],
        "type" => "Announce"
      }

      conn =
        conn
        |> assign(:valid_signature, true)
        |> put_req_header("content-type", "application/activity+json")
        |> post("/users/#{user.nickname}/inbox", data)

      assert "ok" == json_response(conn, 200)
      ObanHelpers.perform(all_enqueued(worker: ReceiverWorker))
      %Activity{} = activity = Activity.get_by_ap_id(data["id"])
      assert "https://www.w3.org/ns/activitystreams#Public" in activity.recipients
    end

    test "it accepts messages from actors that are followed by the user", %{
      conn: conn,
      data: data
    } do
      recipient = insert(:user)
      actor = insert(:user, %{ap_id: "http://mastodon.example.org/users/actor"})

      {:ok, recipient} = User.follow(recipient, actor)

      object =
        data["object"]
        |> Map.put("attributedTo", actor.ap_id)

      data =
        data
        |> Map.put("actor", actor.ap_id)
        |> Map.put("object", object)

      conn =
        conn
        |> assign(:valid_signature, true)
        |> put_req_header("content-type", "application/activity+json")
        |> post("/users/#{recipient.nickname}/inbox", data)

      assert "ok" == json_response(conn, 200)
      ObanHelpers.perform(all_enqueued(worker: ReceiverWorker))
      assert Activity.get_by_ap_id(data["id"])
    end

    test "it rejects reads from other users", %{conn: conn} do
      user = insert(:user)
      otheruser = insert(:user)

      conn =
        conn
        |> assign(:user, otheruser)
        |> put_req_header("accept", "application/activity+json")
        |> get("/users/#{user.nickname}/inbox")

      assert json_response(conn, 403)
    end

    test "it doesn't crash without an authenticated user", %{conn: conn} do
      user = insert(:user)

      conn =
        conn
        |> put_req_header("accept", "application/activity+json")
        |> get("/users/#{user.nickname}/inbox")

      assert json_response(conn, 403)
    end

    test "it returns a note activity in a collection", %{conn: conn} do
      note_activity = insert(:direct_note_activity)
      note_object = Object.normalize(note_activity)
      user = User.get_cached_by_ap_id(hd(note_activity.data["to"]))

      conn =
        conn
        |> assign(:user, user)
        |> put_req_header("accept", "application/activity+json")
        |> get("/users/#{user.nickname}/inbox?page=true")

      assert response(conn, 200) =~ note_object.data["content"]
    end

    test "it clears `unreachable` federation status of the sender", %{conn: conn, data: data} do
      user = insert(:user)
      data = Map.put(data, "bcc", [user.ap_id])

      sender_host = URI.parse(data["actor"]).host
      Instances.set_consistently_unreachable(sender_host)
      refute Instances.reachable?(sender_host)

      conn =
        conn
        |> assign(:valid_signature, true)
        |> put_req_header("content-type", "application/activity+json")
        |> post("/users/#{user.nickname}/inbox", data)

      assert "ok" == json_response(conn, 200)
      assert Instances.reachable?(sender_host)
    end

    test "it removes all follower collections but actor's", %{conn: conn} do
      [actor, recipient] = insert_pair(:user)

      data =
        File.read!("test/fixtures/activitypub-client-post-activity.json")
        |> Poison.decode!()

      object = Map.put(data["object"], "attributedTo", actor.ap_id)

      data =
        data
        |> Map.put("id", Utils.generate_object_id())
        |> Map.put("actor", actor.ap_id)
        |> Map.put("object", object)
        |> Map.put("cc", [
          recipient.follower_address,
          actor.follower_address
        ])
        |> Map.put("to", [
          recipient.ap_id,
          recipient.follower_address,
          "https://www.w3.org/ns/activitystreams#Public"
        ])

      conn
      |> assign(:valid_signature, true)
      |> put_req_header("content-type", "application/activity+json")
      |> post("/users/#{recipient.nickname}/inbox", data)
      |> json_response(200)

      ObanHelpers.perform(all_enqueued(worker: ReceiverWorker))

      activity = Activity.get_by_ap_id(data["id"])

      assert activity.id
      assert actor.follower_address in activity.recipients
      assert actor.follower_address in activity.data["cc"]

      refute recipient.follower_address in activity.recipients
      refute recipient.follower_address in activity.data["cc"]
      refute recipient.follower_address in activity.data["to"]
    end
  end

  describe "/users/:nickname/outbox" do
    test "it will not bomb when there is no activity", %{conn: conn} do
      user = insert(:user)

      conn =
        conn
        |> put_req_header("accept", "application/activity+json")
        |> get("/users/#{user.nickname}/outbox")

      result = json_response(conn, 200)
      assert user.ap_id <> "/outbox" == result["id"]
    end

    test "it returns a note activity in a collection", %{conn: conn} do
      note_activity = insert(:note_activity)
      note_object = Object.normalize(note_activity)
      user = User.get_cached_by_ap_id(note_activity.data["actor"])

      conn =
        conn
        |> put_req_header("accept", "application/activity+json")
        |> get("/users/#{user.nickname}/outbox?page=true")

      assert response(conn, 200) =~ note_object.data["content"]
    end

    test "it returns an announce activity in a collection", %{conn: conn} do
      announce_activity = insert(:announce_activity)
      user = User.get_cached_by_ap_id(announce_activity.data["actor"])

      conn =
        conn
        |> put_req_header("accept", "application/activity+json")
        |> get("/users/#{user.nickname}/outbox?page=true")

      assert response(conn, 200) =~ announce_activity.data["object"]
    end

    test "it rejects posts from other users", %{conn: conn} do
      data = File.read!("test/fixtures/activitypub-client-post-activity.json") |> Poison.decode!()
      user = insert(:user)
      otheruser = insert(:user)

      conn =
        conn
        |> assign(:user, otheruser)
        |> put_req_header("content-type", "application/activity+json")
        |> post("/users/#{user.nickname}/outbox", data)

      assert json_response(conn, 403)
    end

    test "it inserts an incoming create activity into the database", %{conn: conn} do
      data = File.read!("test/fixtures/activitypub-client-post-activity.json") |> Poison.decode!()
      user = insert(:user)

      conn =
        conn
        |> assign(:user, user)
        |> put_req_header("content-type", "application/activity+json")
        |> post("/users/#{user.nickname}/outbox", data)

      result = json_response(conn, 201)

      assert Activity.get_by_ap_id(result["id"])
    end

    test "it rejects an incoming activity with bogus type", %{conn: conn} do
      data = File.read!("test/fixtures/activitypub-client-post-activity.json") |> Poison.decode!()
      user = insert(:user)

      data =
        data
        |> Map.put("type", "BadType")

      conn =
        conn
        |> assign(:user, user)
        |> put_req_header("content-type", "application/activity+json")
        |> post("/users/#{user.nickname}/outbox", data)

      assert json_response(conn, 400)
    end

    test "it erects a tombstone when receiving a delete activity", %{conn: conn} do
      note_activity = insert(:note_activity)
      note_object = Object.normalize(note_activity)
      user = User.get_cached_by_ap_id(note_activity.data["actor"])

      data = %{
        type: "Delete",
        object: %{
          id: note_object.data["id"]
        }
      }

      conn =
        conn
        |> assign(:user, user)
        |> put_req_header("content-type", "application/activity+json")
        |> post("/users/#{user.nickname}/outbox", data)

      result = json_response(conn, 201)
      assert Activity.get_by_ap_id(result["id"])

      assert object = Object.get_by_ap_id(note_object.data["id"])
      assert object.data["type"] == "Tombstone"
    end

    test "it rejects delete activity of object from other actor", %{conn: conn} do
      note_activity = insert(:note_activity)
      note_object = Object.normalize(note_activity)
      user = insert(:user)

      data = %{
        type: "Delete",
        object: %{
          id: note_object.data["id"]
        }
      }

      conn =
        conn
        |> assign(:user, user)
        |> put_req_header("content-type", "application/activity+json")
        |> post("/users/#{user.nickname}/outbox", data)

      assert json_response(conn, 400)
    end

    test "it increases like count when receiving a like action", %{conn: conn} do
      note_activity = insert(:note_activity)
      note_object = Object.normalize(note_activity)
      user = User.get_cached_by_ap_id(note_activity.data["actor"])

      data = %{
        type: "Like",
        object: %{
          id: note_object.data["id"]
        }
      }

      conn =
        conn
        |> assign(:user, user)
        |> put_req_header("content-type", "application/activity+json")
        |> post("/users/#{user.nickname}/outbox", data)

      result = json_response(conn, 201)
      assert Activity.get_by_ap_id(result["id"])

      assert object = Object.get_by_ap_id(note_object.data["id"])
      assert object.data["like_count"] == 1
    end
  end

  describe "/relay/followers" do
    test "it returns relay followers", %{conn: conn} do
      relay_actor = Relay.get_actor()
      user = insert(:user)
      User.follow(user, relay_actor)

      result =
        conn
        |> assign(:relay, true)
        |> get("/relay/followers")
        |> json_response(200)

      assert result["first"]["orderedItems"] == [user.ap_id]
    end
  end

  describe "/relay/following" do
    test "it returns relay following", %{conn: conn} do
      result =
        conn
        |> assign(:relay, true)
        |> get("/relay/following")
        |> json_response(200)

      assert result["first"]["orderedItems"] == []
    end
  end

  describe "/users/:nickname/followers" do
    test "it returns the followers in a collection", %{conn: conn} do
      user = insert(:user)
      user_two = insert(:user)
      User.follow(user, user_two)

      result =
        conn
        |> get("/users/#{user_two.nickname}/followers")
        |> json_response(200)

      assert result["first"]["orderedItems"] == [user.ap_id]
    end

    test "it returns returns a uri if the user has 'hide_followers' set", %{conn: conn} do
      user = insert(:user)
      user_two = insert(:user, hide_followers: true)
      User.follow(user, user_two)

      result =
        conn
        |> get("/users/#{user_two.nickname}/followers")
        |> json_response(200)

      assert is_binary(result["first"])
    end

    test "it returns a 403 error on pages, if the user has 'hide_followers' set and the request is not authenticated",
         %{conn: conn} do
      user = insert(:user, hide_followers: true)

      result =
        conn
        |> get("/users/#{user.nickname}/followers?page=1")

      assert result.status == 403
      assert result.resp_body == ""
    end

    test "it renders the page, if the user has 'hide_followers' set and the request is authenticated with the same user",
         %{conn: conn} do
      user = insert(:user, hide_followers: true)
      other_user = insert(:user)
      {:ok, _other_user, user, _activity} = CommonAPI.follow(other_user, user)

      result =
        conn
        |> assign(:user, user)
        |> get("/users/#{user.nickname}/followers?page=1")
        |> json_response(200)

      assert result["totalItems"] == 1
      assert result["orderedItems"] == [other_user.ap_id]
    end

    test "it works for more than 10 users", %{conn: conn} do
      user = insert(:user)

      Enum.each(1..15, fn _ ->
        other_user = insert(:user)
        User.follow(other_user, user)
      end)

      result =
        conn
        |> get("/users/#{user.nickname}/followers")
        |> json_response(200)

      assert length(result["first"]["orderedItems"]) == 10
      assert result["first"]["totalItems"] == 15
      assert result["totalItems"] == 15

      result =
        conn
        |> get("/users/#{user.nickname}/followers?page=2")
        |> json_response(200)

      assert length(result["orderedItems"]) == 5
      assert result["totalItems"] == 15
    end
  end

  describe "/users/:nickname/following" do
    test "it returns the following in a collection", %{conn: conn} do
      user = insert(:user)
      user_two = insert(:user)
      User.follow(user, user_two)

      result =
        conn
        |> get("/users/#{user.nickname}/following")
        |> json_response(200)

      assert result["first"]["orderedItems"] == [user_two.ap_id]
    end

    test "it returns a uri if the user has 'hide_follows' set", %{conn: conn} do
      user = insert(:user, hide_follows: true)
      user_two = insert(:user)
      User.follow(user, user_two)

      result =
        conn
        |> get("/users/#{user.nickname}/following")
        |> json_response(200)

      assert is_binary(result["first"])
    end

    test "it returns a 403 error on pages, if the user has 'hide_follows' set and the request is not authenticated",
         %{conn: conn} do
      user = insert(:user, hide_follows: true)

      result =
        conn
        |> get("/users/#{user.nickname}/following?page=1")

      assert result.status == 403
      assert result.resp_body == ""
    end

    test "it renders the page, if the user has 'hide_follows' set and the request is authenticated with the same user",
         %{conn: conn} do
      user = insert(:user, hide_follows: true)
      other_user = insert(:user)
      {:ok, user, _other_user, _activity} = CommonAPI.follow(user, other_user)

      result =
        conn
        |> assign(:user, user)
        |> get("/users/#{user.nickname}/following?page=1")
        |> json_response(200)

      assert result["totalItems"] == 1
      assert result["orderedItems"] == [other_user.ap_id]
    end

    test "it works for more than 10 users", %{conn: conn} do
      user = insert(:user)

      Enum.each(1..15, fn _ ->
        user = User.get_cached_by_id(user.id)
        other_user = insert(:user)
        User.follow(user, other_user)
      end)

      result =
        conn
        |> get("/users/#{user.nickname}/following")
        |> json_response(200)

      assert length(result["first"]["orderedItems"]) == 10
      assert result["first"]["totalItems"] == 15
      assert result["totalItems"] == 15

      result =
        conn
        |> get("/users/#{user.nickname}/following?page=2")
        |> json_response(200)

      assert length(result["orderedItems"]) == 5
      assert result["totalItems"] == 15
    end
  end

  describe "delivery tracking" do
    test "it tracks a signed object fetch", %{conn: conn} do
      user = insert(:user, local: false)
      activity = insert(:note_activity)
      object = Object.normalize(activity)

      object_path = String.trim_leading(object.data["id"], Pleroma.Web.Endpoint.url())

      conn
      |> put_req_header("accept", "application/activity+json")
      |> assign(:user, user)
      |> get(object_path)
      |> json_response(200)

      assert Delivery.get(object.id, user.id)
    end

    test "it tracks a signed activity fetch", %{conn: conn} do
      user = insert(:user, local: false)
      activity = insert(:note_activity)
      object = Object.normalize(activity)

      activity_path = String.trim_leading(activity.data["id"], Pleroma.Web.Endpoint.url())

      conn
      |> put_req_header("accept", "application/activity+json")
      |> assign(:user, user)
      |> get(activity_path)
      |> json_response(200)

      assert Delivery.get(object.id, user.id)
    end

    test "it tracks a signed object fetch when the json is cached", %{conn: conn} do
      user = insert(:user, local: false)
      other_user = insert(:user, local: false)
      activity = insert(:note_activity)
      object = Object.normalize(activity)

      object_path = String.trim_leading(object.data["id"], Pleroma.Web.Endpoint.url())

      conn
      |> put_req_header("accept", "application/activity+json")
      |> assign(:user, user)
      |> get(object_path)
      |> json_response(200)

      build_conn()
      |> put_req_header("accept", "application/activity+json")
      |> assign(:user, other_user)
      |> get(object_path)
      |> json_response(200)

      assert Delivery.get(object.id, user.id)
      assert Delivery.get(object.id, other_user.id)
    end

    test "it tracks a signed activity fetch when the json is cached", %{conn: conn} do
      user = insert(:user, local: false)
      other_user = insert(:user, local: false)
      activity = insert(:note_activity)
      object = Object.normalize(activity)

      activity_path = String.trim_leading(activity.data["id"], Pleroma.Web.Endpoint.url())

      conn
      |> put_req_header("accept", "application/activity+json")
      |> assign(:user, user)
      |> get(activity_path)
      |> json_response(200)

      build_conn()
      |> put_req_header("accept", "application/activity+json")
      |> assign(:user, other_user)
      |> get(activity_path)
      |> json_response(200)

      assert Delivery.get(object.id, user.id)
      assert Delivery.get(object.id, other_user.id)
    end
  end

  describe "Additionnal ActivityPub C2S endpoints" do
    test "/api/ap/whoami", %{conn: conn} do
      user = insert(:user)

      conn =
        conn
        |> assign(:user, user)
        |> get("/api/ap/whoami")

      user = User.get_cached_by_id(user.id)

      assert UserView.render("user.json", %{user: user}) == json_response(conn, 200)
    end

    clear_config([:media_proxy])
    clear_config([Pleroma.Upload])

    test "uploadMedia", %{conn: conn} do
      user = insert(:user)

      desc = "Description of the image"

      image = %Plug.Upload{
        content_type: "image/jpg",
        path: Path.absname("test/fixtures/image.jpg"),
        filename: "an_image.jpg"
      }

      conn =
        conn
        |> assign(:user, user)
        |> post("/api/ap/upload_media", %{"file" => image, "description" => desc})

      assert object = json_response(conn, :created)
      assert object["name"] == desc
      assert object["type"] == "Document"
      assert object["actor"] == user.ap_id
    end
  end
end
