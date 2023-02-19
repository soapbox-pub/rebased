# Pleroma: A lightweight social networking server
# Copyright © 2017-2022 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.ActivityPub.ActivityPubControllerTest do
  use Pleroma.Web.ConnCase
  use Oban.Testing, repo: Pleroma.Repo

  alias Pleroma.Activity
  alias Pleroma.Delivery
  alias Pleroma.Instances
  alias Pleroma.Object
  alias Pleroma.Tests.ObanHelpers
  alias Pleroma.User
  alias Pleroma.Web.ActivityPub.ActivityPub
  alias Pleroma.Web.ActivityPub.ObjectView
  alias Pleroma.Web.ActivityPub.Relay
  alias Pleroma.Web.ActivityPub.UserView
  alias Pleroma.Web.ActivityPub.Utils
  alias Pleroma.Web.CommonAPI
  alias Pleroma.Web.Endpoint
  alias Pleroma.Workers.ReceiverWorker

  import Pleroma.Factory

  require Pleroma.Constants

  setup_all do
    Tesla.Mock.mock_global(fn env -> apply(HttpRequestMock, :request, [env]) end)
    :ok
  end

  setup do: clear_config([:instance, :federating], true)

  describe "/relay" do
    setup do: clear_config([:instance, :allow_relay])

    test "with the relay active, it returns the relay user", %{conn: conn} do
      res =
        conn
        |> get(activity_pub_path(conn, :relay))
        |> json_response(200)

      assert res["id"] =~ "/relay"
    end

    test "with the relay disabled, it returns 404", %{conn: conn} do
      clear_config([:instance, :allow_relay], false)

      conn
      |> get(activity_pub_path(conn, :relay))
      |> json_response(404)
    end

    test "on non-federating instance, it returns 404", %{conn: conn} do
      clear_config([:instance, :federating], false)
      user = insert(:user)

      conn
      |> assign(:user, user)
      |> get(activity_pub_path(conn, :relay))
      |> json_response(404)
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

    test "on non-federating instance, it returns 404", %{conn: conn} do
      clear_config([:instance, :federating], false)
      user = insert(:user)

      conn
      |> assign(:user, user)
      |> get(activity_pub_path(conn, :internal_fetch))
      |> json_response(404)
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

    test "it returns error when user is not found", %{conn: conn} do
      response =
        conn
        |> put_req_header("accept", "application/json")
        |> get("/users/jimm")
        |> json_response(404)

      assert response == "Not found"
    end
  end

  describe "mastodon compatibility routes" do
    test "it returns a json representation of the object with accept application/json", %{
      conn: conn
    } do
      {:ok, object} =
        %{
          "type" => "Note",
          "content" => "hey",
          "id" => Endpoint.url() <> "/users/raymoo/statuses/999999999",
          "actor" => Endpoint.url() <> "/users/raymoo",
          "to" => [Pleroma.Constants.as_public()]
        }
        |> Object.create()

      conn =
        conn
        |> put_req_header("accept", "application/json")
        |> get("/users/raymoo/statuses/999999999")

      assert json_response(conn, 200) == ObjectView.render("object.json", %{object: object})
    end

    test "it returns a json representation of the activity with accept application/json", %{
      conn: conn
    } do
      {:ok, object} =
        %{
          "type" => "Note",
          "content" => "hey",
          "id" => Endpoint.url() <> "/users/raymoo/statuses/999999999",
          "actor" => Endpoint.url() <> "/users/raymoo",
          "to" => [Pleroma.Constants.as_public()]
        }
        |> Object.create()

      {:ok, activity, _} =
        %{
          "id" => object.data["id"] <> "/activity",
          "type" => "Create",
          "object" => object.data["id"],
          "actor" => object.data["actor"],
          "to" => object.data["to"]
        }
        |> ActivityPub.persist(local: true)

      conn =
        conn
        |> put_req_header("accept", "application/json")
        |> get("/users/raymoo/statuses/999999999/activity")

      assert json_response(conn, 200) == ObjectView.render("object.json", %{object: activity})
    end
  end

  describe "/objects/:uuid" do
    test "it doesn't return a local-only object", %{conn: conn} do
      user = insert(:user)
      {:ok, post} = CommonAPI.post(user, %{status: "test", visibility: "local"})

      assert Pleroma.Web.ActivityPub.Visibility.is_local_public?(post)

      object = Object.normalize(post, fetch: false)
      uuid = String.split(object.data["id"], "/") |> List.last()

      conn =
        conn
        |> put_req_header("accept", "application/json")
        |> get("/objects/#{uuid}")

      assert json_response(conn, 404)
    end

    test "returns local-only objects when authenticated", %{conn: conn} do
      user = insert(:user)
      {:ok, post} = CommonAPI.post(user, %{status: "test", visibility: "local"})

      assert Pleroma.Web.ActivityPub.Visibility.is_local_public?(post)

      object = Object.normalize(post, fetch: false)
      uuid = String.split(object.data["id"], "/") |> List.last()

      assert response =
               conn
               |> assign(:user, user)
               |> put_req_header("accept", "application/activity+json")
               |> get("/objects/#{uuid}")

      assert json_response(response, 200) == ObjectView.render("object.json", %{object: object})
    end

    test "does not return local-only objects for remote users", %{conn: conn} do
      user = insert(:user)
      reader = insert(:user, local: false)

      {:ok, post} =
        CommonAPI.post(user, %{status: "test @#{reader.nickname}", visibility: "local"})

      assert Pleroma.Web.ActivityPub.Visibility.is_local_public?(post)

      object = Object.normalize(post, fetch: false)
      uuid = String.split(object.data["id"], "/") |> List.last()

      assert response =
               conn
               |> assign(:user, reader)
               |> put_req_header("accept", "application/activity+json")
               |> get("/objects/#{uuid}")

      json_response(response, 404)
    end

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

    test "does not cache authenticated response", %{conn: conn} do
      user = insert(:user)
      reader = insert(:user)

      {:ok, post} =
        CommonAPI.post(user, %{status: "test @#{reader.nickname}", visibility: "local"})

      object = Object.normalize(post, fetch: false)
      uuid = String.split(object.data["id"], "/") |> List.last()

      assert response =
               conn
               |> assign(:user, reader)
               |> put_req_header("accept", "application/activity+json")
               |> get("/objects/#{uuid}")

      json_response(response, 200)

      conn
      |> put_req_header("accept", "application/activity+json")
      |> get("/objects/#{uuid}")
      |> json_response(404)
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

    test "returns visible non-public messages when authenticated", %{conn: conn} do
      note = insert(:direct_note)
      uuid = String.split(note.data["id"], "/") |> List.last()
      user = User.get_by_ap_id(note.data["actor"])
      marisa = insert(:user)

      assert conn
             |> assign(:user, marisa)
             |> put_req_header("accept", "application/activity+json")
             |> get("/objects/#{uuid}")
             |> json_response(404)

      assert response =
               conn
               |> assign(:user, user)
               |> put_req_header("accept", "application/activity+json")
               |> get("/objects/#{uuid}")
               |> json_response(200)

      assert response == ObjectView.render("object.json", %{object: note})
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
    test "it doesn't return a local-only activity", %{conn: conn} do
      user = insert(:user)
      {:ok, post} = CommonAPI.post(user, %{status: "test", visibility: "local"})

      assert Pleroma.Web.ActivityPub.Visibility.is_local_public?(post)

      uuid = String.split(post.data["id"], "/") |> List.last()

      conn =
        conn
        |> put_req_header("accept", "application/json")
        |> get("/activities/#{uuid}")

      assert json_response(conn, 404)
    end

    test "returns local-only activities when authenticated", %{conn: conn} do
      user = insert(:user)
      {:ok, post} = CommonAPI.post(user, %{status: "test", visibility: "local"})

      assert Pleroma.Web.ActivityPub.Visibility.is_local_public?(post)

      uuid = String.split(post.data["id"], "/") |> List.last()

      assert response =
               conn
               |> assign(:user, user)
               |> put_req_header("accept", "application/activity+json")
               |> get("/activities/#{uuid}")

      assert json_response(response, 200) == ObjectView.render("object.json", %{object: post})
    end

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

    test "returns visible non-public messages when authenticated", %{conn: conn} do
      note = insert(:direct_note_activity)
      uuid = String.split(note.data["id"], "/") |> List.last()
      user = User.get_by_ap_id(note.data["actor"])
      marisa = insert(:user)

      assert conn
             |> assign(:user, marisa)
             |> put_req_header("accept", "application/activity+json")
             |> get("/activities/#{uuid}")
             |> json_response(404)

      assert response =
               conn
               |> assign(:user, user)
               |> put_req_header("accept", "application/activity+json")
               |> get("/activities/#{uuid}")
               |> json_response(200)

      assert response == ObjectView.render("object.json", %{object: note})
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
      {:ok, activity} = CommonAPI.post(user, %{status: "cofe"})

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
      data = File.read!("test/fixtures/mastodon-post-activity.json") |> Jason.decode!()

      conn =
        conn
        |> assign(:valid_signature, true)
        |> put_req_header("content-type", "application/activity+json")
        |> post("/inbox", data)

      assert "ok" == json_response(conn, 200)

      ObanHelpers.perform(all_enqueued(worker: ReceiverWorker))
      assert Activity.get_by_ap_id(data["id"])
    end

    @tag capture_log: true
    test "it inserts an incoming activity into the database" <>
           "even if we can't fetch the user but have it in our db",
         %{conn: conn} do
      user =
        insert(:user,
          ap_id: "https://mastodon.example.org/users/raymoo",
          ap_enabled: true,
          local: false,
          last_refreshed_at: nil
        )

      data =
        File.read!("test/fixtures/mastodon-post-activity.json")
        |> Jason.decode!()
        |> Map.put("actor", user.ap_id)
        |> put_in(["object", "attributedTo"], user.ap_id)

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
      data = File.read!("test/fixtures/mastodon-post-activity.json") |> Jason.decode!()

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

    test "accept follow activity", %{conn: conn} do
      clear_config([:instance, :federating], true)
      relay = Relay.get_actor()

      assert {:ok, %Activity{} = activity} = Relay.follow("https://relay.mastodon.host/actor")

      followed_relay = Pleroma.User.get_by_ap_id("https://relay.mastodon.host/actor")
      relay = refresh_record(relay)

      accept =
        File.read!("test/fixtures/relay/accept-follow.json")
        |> String.replace("{{ap_id}}", relay.ap_id)
        |> String.replace("{{activity_id}}", activity.data["id"])

      assert "ok" ==
               conn
               |> assign(:valid_signature, true)
               |> put_req_header("content-type", "application/activity+json")
               |> post("/inbox", accept)
               |> json_response(200)

      ObanHelpers.perform(all_enqueued(worker: ReceiverWorker))

      assert Pleroma.FollowingRelationship.following?(
               relay,
               followed_relay
             )

      Mix.shell(Mix.Shell.Process)

      on_exit(fn ->
        Mix.shell(Mix.Shell.IO)
      end)

      :ok = Mix.Tasks.Pleroma.Relay.run(["list"])
      assert_receive {:mix_shell, :info, ["https://relay.mastodon.host/actor"]}
    end

    @tag capture_log: true
    test "without valid signature, " <>
           "it only accepts Create activities and requires enabled federation",
         %{conn: conn} do
      data = File.read!("test/fixtures/mastodon-post-activity.json") |> Jason.decode!()
      non_create_data = File.read!("test/fixtures/mastodon-announce.json") |> Jason.decode!()

      conn = put_req_header(conn, "content-type", "application/activity+json")

      clear_config([:instance, :federating], false)

      conn
      |> post("/inbox", data)
      |> json_response(403)

      conn
      |> post("/inbox", non_create_data)
      |> json_response(403)

      clear_config([:instance, :federating], true)

      ret_conn = post(conn, "/inbox", data)
      assert "ok" == json_response(ret_conn, 200)

      conn
      |> post("/inbox", non_create_data)
      |> json_response(400)
    end

    test "accepts Add/Remove activities", %{conn: conn} do
      object_id = "c61d6733-e256-4fe1-ab13-1e369789423f"

      status =
        File.read!("test/fixtures/statuses/note.json")
        |> String.replace("{{nickname}}", "lain")
        |> String.replace("{{object_id}}", object_id)

      object_url = "https://example.com/objects/#{object_id}"

      user =
        File.read!("test/fixtures/users_mock/user.json")
        |> String.replace("{{nickname}}", "lain")

      actor = "https://example.com/users/lain"

      Tesla.Mock.mock(fn
        %{
          method: :get,
          url: ^object_url
        } ->
          %Tesla.Env{
            status: 200,
            body: status,
            headers: [{"content-type", "application/activity+json"}]
          }

        %{
          method: :get,
          url: ^actor
        } ->
          %Tesla.Env{
            status: 200,
            body: user,
            headers: [{"content-type", "application/activity+json"}]
          }

        %{method: :get, url: "https://example.com/users/lain/collections/featured"} ->
          %Tesla.Env{
            status: 200,
            body:
              "test/fixtures/users_mock/masto_featured.json"
              |> File.read!()
              |> String.replace("{{domain}}", "example.com")
              |> String.replace("{{nickname}}", "lain"),
            headers: [{"content-type", "application/activity+json"}]
          }
      end)

      data = %{
        "id" => "https://example.com/objects/d61d6733-e256-4fe1-ab13-1e369789423f",
        "actor" => actor,
        "object" => object_url,
        "target" => "https://example.com/users/lain/collections/featured",
        "type" => "Add",
        "to" => [Pleroma.Constants.as_public()]
      }

      assert "ok" ==
               conn
               |> assign(:valid_signature, true)
               |> put_req_header("content-type", "application/activity+json")
               |> post("/inbox", data)
               |> json_response(200)

      ObanHelpers.perform(all_enqueued(worker: ReceiverWorker))
      assert Activity.get_by_ap_id(data["id"])
      user = User.get_cached_by_ap_id(data["actor"])
      assert user.pinned_objects[data["object"]]

      data = %{
        "id" => "https://example.com/objects/d61d6733-e256-4fe1-ab13-1e369789423d",
        "actor" => actor,
        "object" => object_url,
        "target" => "https://example.com/users/lain/collections/featured",
        "type" => "Remove",
        "to" => [Pleroma.Constants.as_public()]
      }

      assert "ok" ==
               conn
               |> assign(:valid_signature, true)
               |> put_req_header("content-type", "application/activity+json")
               |> post("/inbox", data)
               |> json_response(200)

      ObanHelpers.perform(all_enqueued(worker: ReceiverWorker))
      user = refresh_record(user)
      refute user.pinned_objects[data["object"]]
    end

    test "mastodon pin/unpin", %{conn: conn} do
      status_id = "105786274556060421"

      status =
        File.read!("test/fixtures/statuses/masto-note.json")
        |> String.replace("{{nickname}}", "lain")
        |> String.replace("{{status_id}}", status_id)

      status_url = "https://example.com/users/lain/statuses/#{status_id}"

      user =
        File.read!("test/fixtures/users_mock/user.json")
        |> String.replace("{{nickname}}", "lain")

      actor = "https://example.com/users/lain"

      Tesla.Mock.mock(fn
        %{
          method: :get,
          url: ^status_url
        } ->
          %Tesla.Env{
            status: 200,
            body: status,
            headers: [{"content-type", "application/activity+json"}]
          }

        %{
          method: :get,
          url: ^actor
        } ->
          %Tesla.Env{
            status: 200,
            body: user,
            headers: [{"content-type", "application/activity+json"}]
          }

        %{method: :get, url: "https://example.com/users/lain/collections/featured"} ->
          %Tesla.Env{
            status: 200,
            body:
              "test/fixtures/users_mock/masto_featured.json"
              |> File.read!()
              |> String.replace("{{domain}}", "example.com")
              |> String.replace("{{nickname}}", "lain"),
            headers: [{"content-type", "application/activity+json"}]
          }
      end)

      data = %{
        "@context" => "https://www.w3.org/ns/activitystreams",
        "actor" => actor,
        "object" => status_url,
        "target" => "https://example.com/users/lain/collections/featured",
        "type" => "Add"
      }

      assert "ok" ==
               conn
               |> assign(:valid_signature, true)
               |> put_req_header("content-type", "application/activity+json")
               |> post("/inbox", data)
               |> json_response(200)

      ObanHelpers.perform(all_enqueued(worker: ReceiverWorker))
      assert Activity.get_by_object_ap_id_with_object(data["object"])
      user = User.get_cached_by_ap_id(data["actor"])
      assert user.pinned_objects[data["object"]]

      data = %{
        "actor" => actor,
        "object" => status_url,
        "target" => "https://example.com/users/lain/collections/featured",
        "type" => "Remove"
      }

      assert "ok" ==
               conn
               |> assign(:valid_signature, true)
               |> put_req_header("content-type", "application/activity+json")
               |> post("/inbox", data)
               |> json_response(200)

      ObanHelpers.perform(all_enqueued(worker: ReceiverWorker))
      assert Activity.get_by_object_ap_id_with_object(data["object"])
      user = refresh_record(user)
      refute user.pinned_objects[data["object"]]
    end
  end

  describe "/users/:nickname/inbox" do
    setup do
      data =
        File.read!("test/fixtures/mastodon-post-activity.json")
        |> Jason.decode!()

      [data: data]
    end

    test "it inserts an incoming activity into the database", %{conn: conn, data: data} do
      user = insert(:user)

      data =
        data
        |> Map.put("bcc", [user.ap_id])
        |> Kernel.put_in(["object", "bcc"], [user.ap_id])

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
        data
        |> Map.put("to", user.ap_id)
        |> Map.put("cc", [])
        |> Kernel.put_in(["object", "to"], user.ap_id)
        |> Kernel.put_in(["object", "cc"], [])

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
        data
        |> Map.put("to", [])
        |> Map.put("cc", user.ap_id)
        |> Kernel.put_in(["object", "to"], [])
        |> Kernel.put_in(["object", "cc"], user.ap_id)

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
        data
        |> Map.put("to", [])
        |> Map.put("cc", [])
        |> Map.put("bcc", user.ap_id)
        |> Kernel.put_in(["object", "to"], [])
        |> Kernel.put_in(["object", "cc"], [])
        |> Kernel.put_in(["object", "bcc"], user.ap_id)

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

      {:ok, post} = CommonAPI.post(user, %{status: "hey"})
      announcer = insert(:user, local: false)

      data = %{
        "@context" => "https://www.w3.org/ns/activitystreams",
        "actor" => announcer.ap_id,
        "id" => "#{announcer.ap_id}/statuses/19512778738411822/activity",
        "object" => post.data["object"],
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

      {:ok, recipient, actor} = User.follow(recipient, actor)

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
      other_user = insert(:user)

      conn =
        conn
        |> assign(:user, other_user)
        |> put_req_header("accept", "application/activity+json")
        |> get("/users/#{user.nickname}/inbox")

      assert json_response(conn, 403)
    end

    test "it returns a note activity in a collection", %{conn: conn} do
      note_activity = insert(:direct_note_activity)
      note_object = Object.normalize(note_activity, fetch: false)
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

    @tag capture_log: true
    test "it removes all follower collections but actor's", %{conn: conn} do
      [actor, recipient] = insert_pair(:user)

      to = [
        recipient.ap_id,
        recipient.follower_address,
        "https://www.w3.org/ns/activitystreams#Public"
      ]

      cc = [recipient.follower_address, actor.follower_address]

      data = %{
        "@context" => ["https://www.w3.org/ns/activitystreams"],
        "type" => "Create",
        "id" => Utils.generate_activity_id(),
        "to" => to,
        "cc" => cc,
        "actor" => actor.ap_id,
        "object" => %{
          "type" => "Note",
          "to" => to,
          "cc" => cc,
          "content" => "It's a note",
          "attributedTo" => actor.ap_id,
          "id" => Utils.generate_object_id()
        }
      }

      conn
      |> assign(:valid_signature, true)
      |> put_req_header("content-type", "application/activity+json")
      |> post("/users/#{recipient.nickname}/inbox", data)
      |> json_response(200)

      ObanHelpers.perform(all_enqueued(worker: ReceiverWorker))

      assert activity = Activity.get_by_ap_id(data["id"])

      assert activity.id
      assert actor.follower_address in activity.recipients
      assert actor.follower_address in activity.data["cc"]

      refute recipient.follower_address in activity.recipients
      refute recipient.follower_address in activity.data["cc"]
      refute recipient.follower_address in activity.data["to"]
    end

    test "it requires authentication", %{conn: conn} do
      user = insert(:user)
      conn = put_req_header(conn, "accept", "application/activity+json")

      ret_conn = get(conn, "/users/#{user.nickname}/inbox")
      assert json_response(ret_conn, 403)

      ret_conn =
        conn
        |> assign(:user, user)
        |> get("/users/#{user.nickname}/inbox")

      assert json_response(ret_conn, 200)
    end

    @tag capture_log: true
    test "forwarded report", %{conn: conn} do
      admin = insert(:user, is_admin: true)
      actor = insert(:user, local: false)
      remote_domain = URI.parse(actor.ap_id).host
      reported_user = insert(:user)

      note = insert(:note_activity, user: reported_user)

      data = %{
        "@context" => [
          "https://www.w3.org/ns/activitystreams",
          "https://#{remote_domain}/schemas/litepub-0.1.jsonld",
          %{
            "@language" => "und"
          }
        ],
        "actor" => actor.ap_id,
        "cc" => [
          reported_user.ap_id
        ],
        "content" => "test",
        "context" => "context",
        "id" => "http://#{remote_domain}/activities/02be56cf-35e3-46b4-b2c6-47ae08dfee9e",
        "nickname" => reported_user.nickname,
        "object" => [
          reported_user.ap_id,
          %{
            "actor" => %{
              "actor_type" => "Person",
              "approval_pending" => false,
              "avatar" => "",
              "confirmation_pending" => false,
              "deactivated" => false,
              "display_name" => "test user",
              "id" => reported_user.id,
              "local" => false,
              "nickname" => reported_user.nickname,
              "registration_reason" => nil,
              "roles" => %{
                "admin" => false,
                "moderator" => false
              },
              "tags" => [],
              "url" => reported_user.ap_id
            },
            "content" => "",
            "id" => note.data["id"],
            "published" => note.data["published"],
            "type" => "Note"
          }
        ],
        "published" => note.data["published"],
        "state" => "open",
        "to" => [],
        "type" => "Flag"
      }

      conn
      |> assign(:valid_signature, true)
      |> put_req_header("content-type", "application/activity+json")
      |> post("/users/#{reported_user.nickname}/inbox", data)
      |> json_response(200)

      ObanHelpers.perform(all_enqueued(worker: ReceiverWorker))

      assert Pleroma.Repo.aggregate(Activity, :count, :id) == 2

      ObanHelpers.perform_all()

      Swoosh.TestAssertions.assert_email_sent(
        to: {admin.name, admin.email},
        html_body: ~r/Reported Account:/i
      )
    end

    @tag capture_log: true
    test "forwarded report from mastodon", %{conn: conn} do
      admin = insert(:user, is_admin: true)
      actor = insert(:user, local: false)
      remote_domain = URI.parse(actor.ap_id).host
      remote_actor = "https://#{remote_domain}/actor"
      [reported_user, another] = insert_list(2, :user)

      note = insert(:note_activity, user: reported_user)

      Pleroma.Web.CommonAPI.favorite(another, note.id)

      mock_json_body =
        "test/fixtures/mastodon/application_actor.json"
        |> File.read!()
        |> String.replace("{{DOMAIN}}", remote_domain)

      Tesla.Mock.mock(fn %{url: ^remote_actor} ->
        %Tesla.Env{
          status: 200,
          body: mock_json_body,
          headers: [{"content-type", "application/activity+json"}]
        }
      end)

      data = %{
        "@context" => "https://www.w3.org/ns/activitystreams",
        "actor" => remote_actor,
        "content" => "test report",
        "id" => "https://#{remote_domain}/e3b12fd1-948c-446e-b93b-a5e67edbe1d8",
        "object" => [
          reported_user.ap_id,
          note.data["object"]
        ],
        "type" => "Flag"
      }

      conn
      |> assign(:valid_signature, true)
      |> put_req_header("content-type", "application/activity+json")
      |> post("/users/#{reported_user.nickname}/inbox", data)
      |> json_response(200)

      ObanHelpers.perform(all_enqueued(worker: ReceiverWorker))

      flag_activity = "Flag" |> Pleroma.Activity.Queries.by_type() |> Pleroma.Repo.one()
      reported_user_ap_id = reported_user.ap_id

      [^reported_user_ap_id, flag_data] = flag_activity.data["object"]

      Enum.each(~w(actor content id published type), &Map.has_key?(flag_data, &1))
      ObanHelpers.perform_all()

      Swoosh.TestAssertions.assert_email_sent(
        to: {admin.name, admin.email},
        html_body: ~r/#{note.data["object"]}/i
      )
    end
  end

  describe "GET /users/:nickname/outbox" do
    test "it paginates correctly", %{conn: conn} do
      user = insert(:user)
      conn = assign(conn, :user, user)
      outbox_endpoint = user.ap_id <> "/outbox"

      _posts =
        for i <- 0..25 do
          {:ok, activity} = CommonAPI.post(user, %{status: "post #{i}"})
          activity
        end

      result =
        conn
        |> put_req_header("accept", "application/activity+json")
        |> get(outbox_endpoint <> "?page=true")
        |> json_response(200)

      result_ids = Enum.map(result["orderedItems"], fn x -> x["id"] end)
      assert length(result["orderedItems"]) == 20
      assert length(result_ids) == 20
      assert result["next"]
      assert String.starts_with?(result["next"], outbox_endpoint)

      result_next =
        conn
        |> put_req_header("accept", "application/activity+json")
        |> get(result["next"])
        |> json_response(200)

      result_next_ids = Enum.map(result_next["orderedItems"], fn x -> x["id"] end)
      assert length(result_next["orderedItems"]) == 6
      assert length(result_next_ids) == 6
      refute Enum.find(result_next_ids, fn x -> x in result_ids end)
      refute Enum.find(result_ids, fn x -> x in result_next_ids end)
      assert String.starts_with?(result["id"], outbox_endpoint)

      result_next_again =
        conn
        |> put_req_header("accept", "application/activity+json")
        |> get(result_next["id"])
        |> json_response(200)

      assert result_next == result_next_again
    end

    test "it returns 200 even if there're no activities", %{conn: conn} do
      user = insert(:user)
      outbox_endpoint = user.ap_id <> "/outbox"

      conn =
        conn
        |> assign(:user, user)
        |> put_req_header("accept", "application/activity+json")
        |> get(outbox_endpoint)

      result = json_response(conn, 200)
      assert outbox_endpoint == result["id"]
    end

    test "it returns a local note activity when authenticated as local user", %{conn: conn} do
      user = insert(:user)
      reader = insert(:user)
      {:ok, note_activity} = CommonAPI.post(user, %{status: "mew mew", visibility: "local"})
      ap_id = note_activity.data["id"]

      resp =
        conn
        |> assign(:user, reader)
        |> put_req_header("accept", "application/activity+json")
        |> get("/users/#{user.nickname}/outbox?page=true")
        |> json_response(200)

      assert %{"orderedItems" => [%{"id" => ^ap_id}]} = resp
    end

    test "it does not return a local note activity when unauthenticated", %{conn: conn} do
      user = insert(:user)
      {:ok, _note_activity} = CommonAPI.post(user, %{status: "mew mew", visibility: "local"})

      resp =
        conn
        |> put_req_header("accept", "application/activity+json")
        |> get("/users/#{user.nickname}/outbox?page=true")
        |> json_response(200)

      assert %{"orderedItems" => []} = resp
    end

    test "it returns a note activity in a collection", %{conn: conn} do
      note_activity = insert(:note_activity)
      note_object = Object.normalize(note_activity, fetch: false)
      user = User.get_cached_by_ap_id(note_activity.data["actor"])

      conn =
        conn
        |> assign(:user, user)
        |> put_req_header("accept", "application/activity+json")
        |> get("/users/#{user.nickname}/outbox?page=true")

      assert response(conn, 200) =~ note_object.data["content"]
    end

    test "it returns an announce activity in a collection", %{conn: conn} do
      announce_activity = insert(:announce_activity)
      user = User.get_cached_by_ap_id(announce_activity.data["actor"])

      conn =
        conn
        |> assign(:user, user)
        |> put_req_header("accept", "application/activity+json")
        |> get("/users/#{user.nickname}/outbox?page=true")

      assert response(conn, 200) =~ announce_activity.data["object"]
    end

    test "It returns poll Answers when authenticated", %{conn: conn} do
      poller = insert(:user)
      voter = insert(:user)

      {:ok, activity} =
        CommonAPI.post(poller, %{
          status: "suya...",
          poll: %{options: ["suya", "suya.", "suya.."], expires_in: 10}
        })

      assert question = Object.normalize(activity, fetch: false)

      {:ok, [activity], _object} = CommonAPI.vote(voter, question, [1])

      assert outbox_get =
               conn
               |> assign(:user, voter)
               |> put_req_header("accept", "application/activity+json")
               |> get(voter.ap_id <> "/outbox?page=true")
               |> json_response(200)

      assert [answer_outbox] = outbox_get["orderedItems"]
      assert answer_outbox["id"] == activity.data["id"]
    end
  end

  describe "POST /users/:nickname/outbox (C2S)" do
    setup do: clear_config([:instance, :limit])

    setup do
      [
        activity: %{
          "@context" => "https://www.w3.org/ns/activitystreams",
          "type" => "Create",
          "object" => %{
            "type" => "Note",
            "content" => "AP C2S test",
            "to" => "https://www.w3.org/ns/activitystreams#Public",
            "cc" => []
          }
        }
      ]
    end

    test "it rejects posts from other users / unauthenticated users", %{
      conn: conn,
      activity: activity
    } do
      user = insert(:user)
      other_user = insert(:user)
      conn = put_req_header(conn, "content-type", "application/activity+json")

      conn
      |> post("/users/#{user.nickname}/outbox", activity)
      |> json_response(403)

      conn
      |> assign(:user, other_user)
      |> post("/users/#{user.nickname}/outbox", activity)
      |> json_response(403)
    end

    test "it inserts an incoming create activity into the database", %{
      conn: conn,
      activity: activity
    } do
      user = insert(:user)

      result =
        conn
        |> assign(:user, user)
        |> put_req_header("content-type", "application/activity+json")
        |> post("/users/#{user.nickname}/outbox", activity)
        |> json_response(201)

      assert Activity.get_by_ap_id(result["id"])
      assert result["object"]
      assert %Object{data: object} = Object.normalize(result["object"], fetch: false)
      assert object["content"] == activity["object"]["content"]
    end

    test "it rejects anything beyond 'Note' creations", %{conn: conn, activity: activity} do
      user = insert(:user)

      activity =
        activity
        |> put_in(["object", "type"], "Benis")

      _result =
        conn
        |> assign(:user, user)
        |> put_req_header("content-type", "application/activity+json")
        |> post("/users/#{user.nickname}/outbox", activity)
        |> json_response(400)
    end

    test "it inserts an incoming sensitive activity into the database", %{
      conn: conn,
      activity: activity
    } do
      user = insert(:user)
      conn = assign(conn, :user, user)
      object = Map.put(activity["object"], "sensitive", true)
      activity = Map.put(activity, "object", object)

      response =
        conn
        |> put_req_header("content-type", "application/activity+json")
        |> post("/users/#{user.nickname}/outbox", activity)
        |> json_response(201)

      assert Activity.get_by_ap_id(response["id"])
      assert response["object"]
      assert %Object{data: response_object} = Object.normalize(response["object"], fetch: false)
      assert response_object["sensitive"] == true
      assert response_object["content"] == activity["object"]["content"]

      representation =
        conn
        |> put_req_header("accept", "application/activity+json")
        |> get(response["id"])
        |> json_response(200)

      assert representation["object"]["sensitive"] == true
    end

    test "it rejects an incoming activity with bogus type", %{conn: conn, activity: activity} do
      user = insert(:user)
      activity = Map.put(activity, "type", "BadType")

      conn =
        conn
        |> assign(:user, user)
        |> put_req_header("content-type", "application/activity+json")
        |> post("/users/#{user.nickname}/outbox", activity)

      assert json_response(conn, 400)
    end

    test "it erects a tombstone when receiving a delete activity", %{conn: conn} do
      note_activity = insert(:note_activity)
      note_object = Object.normalize(note_activity, fetch: false)
      user = User.get_cached_by_ap_id(note_activity.data["actor"])

      data = %{
        "type" => "Delete",
        "object" => %{
          "id" => note_object.data["id"]
        }
      }

      result =
        conn
        |> assign(:user, user)
        |> put_req_header("content-type", "application/activity+json")
        |> post("/users/#{user.nickname}/outbox", data)
        |> json_response(201)

      assert Activity.get_by_ap_id(result["id"])

      assert object = Object.get_by_ap_id(note_object.data["id"])
      assert object.data["type"] == "Tombstone"
    end

    test "it rejects delete activity of object from other actor", %{conn: conn} do
      note_activity = insert(:note_activity)
      note_object = Object.normalize(note_activity, fetch: false)
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

      assert json_response(conn, 403)
    end

    test "it increases like count when receiving a like action", %{conn: conn} do
      note_activity = insert(:note_activity)
      note_object = Object.normalize(note_activity, fetch: false)
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

    test "it doesn't spreads faulty attributedTo or actor fields", %{
      conn: conn,
      activity: activity
    } do
      reimu = insert(:user, nickname: "reimu")
      cirno = insert(:user, nickname: "cirno")

      assert reimu.ap_id
      assert cirno.ap_id

      activity =
        activity
        |> put_in(["object", "actor"], reimu.ap_id)
        |> put_in(["object", "attributedTo"], reimu.ap_id)
        |> put_in(["actor"], reimu.ap_id)
        |> put_in(["attributedTo"], reimu.ap_id)

      _reimu_outbox =
        conn
        |> assign(:user, cirno)
        |> put_req_header("content-type", "application/activity+json")
        |> post("/users/#{reimu.nickname}/outbox", activity)
        |> json_response(403)

      cirno_outbox =
        conn
        |> assign(:user, cirno)
        |> put_req_header("content-type", "application/activity+json")
        |> post("/users/#{cirno.nickname}/outbox", activity)
        |> json_response(201)

      assert cirno_outbox["attributedTo"] == nil
      assert cirno_outbox["actor"] == cirno.ap_id

      assert cirno_object = Object.normalize(cirno_outbox["object"], fetch: false)
      assert cirno_object.data["actor"] == cirno.ap_id
      assert cirno_object.data["attributedTo"] == cirno.ap_id
    end

    test "Character limitation", %{conn: conn, activity: activity} do
      clear_config([:instance, :limit], 5)
      user = insert(:user)

      result =
        conn
        |> assign(:user, user)
        |> put_req_header("content-type", "application/activity+json")
        |> post("/users/#{user.nickname}/outbox", activity)
        |> json_response(400)

      assert result == "Character limit (5 characters) exceeded, contains 11 characters"
    end
  end

  describe "/relay/followers" do
    test "it returns relay followers", %{conn: conn} do
      relay_actor = Relay.get_actor()
      user = insert(:user)
      User.follow(user, relay_actor)

      result =
        conn
        |> get("/relay/followers")
        |> json_response(200)

      assert result["first"]["orderedItems"] == [user.ap_id]
    end

    test "on non-federating instance, it returns 404", %{conn: conn} do
      clear_config([:instance, :federating], false)
      user = insert(:user)

      conn
      |> assign(:user, user)
      |> get("/relay/followers")
      |> json_response(404)
    end
  end

  describe "/relay/following" do
    test "it returns relay following", %{conn: conn} do
      result =
        conn
        |> get("/relay/following")
        |> json_response(200)

      assert result["first"]["orderedItems"] == []
    end

    test "on non-federating instance, it returns 404", %{conn: conn} do
      clear_config([:instance, :federating], false)
      user = insert(:user)

      conn
      |> assign(:user, user)
      |> get("/relay/following")
      |> json_response(404)
    end
  end

  describe "/users/:nickname/followers" do
    test "it returns the followers in a collection", %{conn: conn} do
      user = insert(:user)
      user_two = insert(:user)
      User.follow(user, user_two)

      result =
        conn
        |> assign(:user, user_two)
        |> get("/users/#{user_two.nickname}/followers")
        |> json_response(200)

      assert result["first"]["orderedItems"] == [user.ap_id]
    end

    test "it returns a uri if the user has 'hide_followers' set", %{conn: conn} do
      user = insert(:user)
      user_two = insert(:user, hide_followers: true)
      User.follow(user, user_two)

      result =
        conn
        |> assign(:user, user)
        |> get("/users/#{user_two.nickname}/followers")
        |> json_response(200)

      assert is_binary(result["first"])
    end

    test "it returns a 403 error on pages, if the user has 'hide_followers' set and the request is from another user",
         %{conn: conn} do
      user = insert(:user)
      other_user = insert(:user, hide_followers: true)

      result =
        conn
        |> assign(:user, user)
        |> get("/users/#{other_user.nickname}/followers?page=1")

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
        |> assign(:user, user)
        |> get("/users/#{user.nickname}/followers")
        |> json_response(200)

      assert length(result["first"]["orderedItems"]) == 10
      assert result["first"]["totalItems"] == 15
      assert result["totalItems"] == 15

      result =
        conn
        |> assign(:user, user)
        |> get("/users/#{user.nickname}/followers?page=2")
        |> json_response(200)

      assert length(result["orderedItems"]) == 5
      assert result["totalItems"] == 15
    end

    test "does not require authentication", %{conn: conn} do
      user = insert(:user)

      conn
      |> get("/users/#{user.nickname}/followers")
      |> json_response(200)
    end
  end

  describe "/users/:nickname/following" do
    test "it returns the following in a collection", %{conn: conn} do
      user = insert(:user)
      user_two = insert(:user)
      User.follow(user, user_two)

      result =
        conn
        |> assign(:user, user)
        |> get("/users/#{user.nickname}/following")
        |> json_response(200)

      assert result["first"]["orderedItems"] == [user_two.ap_id]
    end

    test "it returns a uri if the user has 'hide_follows' set", %{conn: conn} do
      user = insert(:user)
      user_two = insert(:user, hide_follows: true)
      User.follow(user, user_two)

      result =
        conn
        |> assign(:user, user)
        |> get("/users/#{user_two.nickname}/following")
        |> json_response(200)

      assert is_binary(result["first"])
    end

    test "it returns a 403 error on pages, if the user has 'hide_follows' set and the request is from another user",
         %{conn: conn} do
      user = insert(:user)
      user_two = insert(:user, hide_follows: true)

      result =
        conn
        |> assign(:user, user)
        |> get("/users/#{user_two.nickname}/following?page=1")

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
        |> assign(:user, user)
        |> get("/users/#{user.nickname}/following")
        |> json_response(200)

      assert length(result["first"]["orderedItems"]) == 10
      assert result["first"]["totalItems"] == 15
      assert result["totalItems"] == 15

      result =
        conn
        |> assign(:user, user)
        |> get("/users/#{user.nickname}/following?page=2")
        |> json_response(200)

      assert length(result["orderedItems"]) == 5
      assert result["totalItems"] == 15
    end

    test "does not require authentication", %{conn: conn} do
      user = insert(:user)

      conn
      |> get("/users/#{user.nickname}/following")
      |> json_response(200)
    end
  end

  describe "delivery tracking" do
    test "it tracks a signed object fetch", %{conn: conn} do
      user = insert(:user, local: false)
      activity = insert(:note_activity)
      object = Object.normalize(activity, fetch: false)

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
      object = Object.normalize(activity, fetch: false)

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
      object = Object.normalize(activity, fetch: false)

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
      object = Object.normalize(activity, fetch: false)

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

  describe "Additional ActivityPub C2S endpoints" do
    test "GET /api/ap/whoami", %{conn: conn} do
      user = insert(:user)

      conn =
        conn
        |> assign(:user, user)
        |> get("/api/ap/whoami")

      user = User.get_cached_by_id(user.id)

      assert UserView.render("user.json", %{user: user}) == json_response(conn, 200)

      conn
      |> get("/api/ap/whoami")
      |> json_response(403)
    end

    setup do: clear_config([:media_proxy])
    setup do: clear_config([Pleroma.Upload])

    test "POST /api/ap/upload_media", %{conn: conn} do
      user = insert(:user)

      desc = "Description of the image"

      image = %Plug.Upload{
        content_type: "image/jpeg",
        path: Path.absname("test/fixtures/image.jpg"),
        filename: "an_image.jpg"
      }

      object =
        conn
        |> assign(:user, user)
        |> post("/api/ap/upload_media", %{"file" => image, "description" => desc})
        |> json_response(:created)

      assert object["name"] == desc
      assert object["type"] == "Document"
      assert object["actor"] == user.ap_id
      assert [%{"href" => object_href, "mediaType" => object_mediatype}] = object["url"]
      assert is_binary(object_href)
      assert object_mediatype == "image/jpeg"
      assert String.ends_with?(object_href, ".jpg")

      activity_request = %{
        "@context" => "https://www.w3.org/ns/activitystreams",
        "type" => "Create",
        "object" => %{
          "type" => "Note",
          "content" => "AP C2S test, attachment",
          "attachment" => [object],
          "to" => "https://www.w3.org/ns/activitystreams#Public",
          "cc" => []
        }
      }

      activity_response =
        conn
        |> assign(:user, user)
        |> post("/users/#{user.nickname}/outbox", activity_request)
        |> json_response(:created)

      assert activity_response["id"]
      assert activity_response["object"]
      assert activity_response["actor"] == user.ap_id

      assert %Object{data: %{"attachment" => [attachment]}} =
               Object.normalize(activity_response["object"], fetch: false)

      assert attachment["type"] == "Document"
      assert attachment["name"] == desc

      assert [
               %{
                 "href" => ^object_href,
                 "type" => "Link",
                 "mediaType" => ^object_mediatype
               }
             ] = attachment["url"]

      # Fails if unauthenticated
      conn
      |> post("/api/ap/upload_media", %{"file" => image, "description" => desc})
      |> json_response(403)
    end
  end

  test "pinned collection", %{conn: conn} do
    clear_config([:instance, :max_pinned_statuses], 2)
    user = insert(:user)
    objects = insert_list(2, :note, user: user)

    Enum.reduce(objects, user, fn %{data: %{"id" => object_id}}, user ->
      {:ok, updated} = User.add_pinned_object_id(user, object_id)
      updated
    end)

    %{nickname: nickname, featured_address: featured_address, pinned_objects: pinned_objects} =
      refresh_record(user)

    %{"id" => ^featured_address, "orderedItems" => items, "totalItems" => 2} =
      conn
      |> get("/users/#{nickname}/collections/featured")
      |> json_response(200)

    object_ids = Enum.map(items, & &1["id"])

    assert Enum.all?(pinned_objects, fn {obj_id, _} ->
             obj_id in object_ids
           end)
  end
end
