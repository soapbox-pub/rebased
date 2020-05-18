# Pleroma: A lightweight social networking server
# Copyright © 2017-2020 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.ActivityPub.Transmogrifier.AnnounceHandlingTest do
  use Pleroma.DataCase

  alias Pleroma.Activity
  alias Pleroma.Object
  alias Pleroma.Web.CommonAPI
  alias Pleroma.Web.ActivityPub.Transmogrifier

  import Pleroma.Factory

  test "it works for incoming honk announces" do
    _user = insert(:user, ap_id: "https://honktest/u/test", local: false)
    other_user = insert(:user)
    {:ok, post} = CommonAPI.post(other_user, %{status: "bonkeronk"})

    announce = %{
      "@context" => "https://www.w3.org/ns/activitystreams",
      "actor" => "https://honktest/u/test",
      "id" => "https://honktest/u/test/bonk/1793M7B9MQ48847vdx",
      "object" => post.data["object"],
      "published" => "2019-06-25T19:33:58Z",
      "to" => "https://www.w3.org/ns/activitystreams#Public",
      "type" => "Announce"
    }

    {:ok, %Activity{local: false}} = Transmogrifier.handle_incoming(announce)
  end

  test "it works for incoming announces with actor being inlined (kroeg)" do
    data = File.read!("test/fixtures/kroeg-announce-with-inline-actor.json") |> Poison.decode!()

    _user = insert(:user, local: false, ap_id: data["actor"]["id"])
    other_user = insert(:user)

    {:ok, post} = CommonAPI.post(other_user, %{status: "kroegeroeg"})

    data =
      data
      |> put_in(["object", "id"], post.data["object"])

    {:ok, %Activity{data: data, local: false}} = Transmogrifier.handle_incoming(data)

    assert data["actor"] == "https://puckipedia.com/"
  end

  test "it works for incoming announces, fetching the announced object" do
    Tesla.Mock.mock_global(fn env -> apply(HttpRequestMock, :request, [env]) end)
    data = File.read!("test/fixtures/mastodon-announce.json") |> Poison.decode!()

    _user = insert(:user, local: false, ap_id: data["actor"])

    {:ok, %Activity{data: data, local: false}} = Transmogrifier.handle_incoming(data)

    assert data["actor"] == "http://mastodon.example.org/users/admin"
    assert data["type"] == "Announce"

    assert data["id"] ==
             "http://mastodon.example.org/users/admin/statuses/99542391527669785/activity"

    assert data["object"] ==
             "http://mastodon.example.org/users/admin/statuses/99541947525187367"

    assert(Activity.get_create_by_object_ap_id(data["object"]))
  end

  @tag capture_log: true
  test "it works for incoming announces with an existing activity" do
    user = insert(:user)
    {:ok, activity} = CommonAPI.post(user, %{status: "hey"})

    data =
      File.read!("test/fixtures/mastodon-announce.json")
      |> Poison.decode!()
      |> Map.put("object", activity.data["object"])

    _user = insert(:user, local: false, ap_id: data["actor"])

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

    _user =
      insert(:user,
        local: false,
        ap_id: data["actor"],
        follower_address: data["actor"] <> "/followers"
      )

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
    Tesla.Mock.mock(fn
      %{method: :get} -> %Tesla.Env{status: 404, body: ""}
    end)

    data =
      File.read!("test/fixtures/bogus-mastodon-announce.json")
      |> Poison.decode!()

    _user = insert(:user, local: false, ap_id: data["actor"])

    assert {:error, e} = Transmogrifier.handle_incoming(data)
  end

  test "it does not clobber the addressing on announce activities" do
    user = insert(:user)
    {:ok, activity} = CommonAPI.post(user, %{status: "hey"})

    data =
      File.read!("test/fixtures/mastodon-announce.json")
      |> Poison.decode!()
      |> Map.put("object", Object.normalize(activity).data["id"])
      |> Map.put("to", ["http://mastodon.example.org/users/admin/followers"])
      |> Map.put("cc", [])

    _user =
      insert(:user,
        local: false,
        ap_id: data["actor"],
        follower_address: "http://mastodon.example.org/users/admin/followers"
      )

    {:ok, %Activity{data: data, local: false}} = Transmogrifier.handle_incoming(data)

    assert data["to"] == ["http://mastodon.example.org/users/admin/followers"]
  end
end
