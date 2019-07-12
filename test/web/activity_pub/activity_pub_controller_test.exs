# Pleroma: A lightweight social networking server
# Copyright © 2017-2018 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.ActivityPub.ActivityPubControllerTest do
  use Pleroma.Web.ConnCase
  import Pleroma.Factory
  alias Pleroma.Activity
  alias Pleroma.Instances
  alias Pleroma.Object
  alias Pleroma.User
  alias Pleroma.Web.ActivityPub.ObjectView
  alias Pleroma.Web.ActivityPub.UserView
  alias Pleroma.Web.ActivityPub.Utils

  setup_all do
    Tesla.Mock.mock_global(fn env -> apply(HttpRequestMock, :request, [env]) end)

    config_path = [:instance, :federating]
    initial_setting = Pleroma.Config.get(config_path)

    Pleroma.Config.put(config_path, true)
    on_exit(fn -> Pleroma.Config.put(config_path, initial_setting) end)

    :ok
  end

  describe "/relay" do
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

      Pleroma.Config.put([:instance, :allow_relay], true)
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
  end

  describe "/object/:uuid/likes" do
    test "it returns the like activities in a collection", %{conn: conn} do
      like = insert(:like_activity)
      like_object_ap_id = Object.normalize(like).data["id"]
      uuid = String.split(like_object_ap_id, "/") |> List.last()

      result =
        conn
        |> put_req_header("accept", "application/activity+json")
        |> get("/objects/#{uuid}/likes")
        |> json_response(200)

      assert List.first(result["first"]["orderedItems"])["id"] == like.data["id"]
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
      :timer.sleep(500)
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
      :timer.sleep(500)
      assert Activity.get_by_ap_id(data["id"])
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
      :timer.sleep(500)
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

    test "it returns a note activity in a collection", %{conn: conn} do
      note_activity = insert(:direct_note_activity)
      note_object = Object.normalize(note_activity)
      user = User.get_cached_by_ap_id(hd(note_activity.data["to"]))

      conn =
        conn
        |> assign(:user, user)
        |> put_req_header("accept", "application/activity+json")
        |> get("/users/#{user.nickname}/inbox")

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
        |> get("/users/#{user.nickname}/outbox")

      assert response(conn, 200) =~ note_object.data["content"]
    end

    test "it returns an announce activity in a collection", %{conn: conn} do
      announce_activity = insert(:announce_activity)
      user = User.get_cached_by_ap_id(announce_activity.data["actor"])

      conn =
        conn
        |> put_req_header("accept", "application/activity+json")
        |> get("/users/#{user.nickname}/outbox")

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
      user_two = insert(:user, %{info: %{hide_followers: true}})
      User.follow(user, user_two)

      result =
        conn
        |> get("/users/#{user_two.nickname}/followers")
        |> json_response(200)

      assert is_binary(result["first"])
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
      user = insert(:user, %{info: %{hide_follows: true}})
      user_two = insert(:user)
      User.follow(user, user_two)

      result =
        conn
        |> get("/users/#{user.nickname}/following")
        |> json_response(200)

      assert is_binary(result["first"])
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
end
