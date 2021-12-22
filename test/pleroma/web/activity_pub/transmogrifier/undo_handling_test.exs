# Pleroma: A lightweight social networking server
# Copyright © 2017-2021 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.ActivityPub.Transmogrifier.UndoHandlingTest do
  use Pleroma.DataCase, async: true

  alias Pleroma.Activity
  alias Pleroma.Object
  alias Pleroma.User
  alias Pleroma.Web.ActivityPub.Transmogrifier
  alias Pleroma.Web.CommonAPI

  import Pleroma.Factory

  test "it works for incoming emoji reaction undos" do
    user = insert(:user)

    {:ok, activity} = CommonAPI.post(user, %{status: "hello"})
    {:ok, reaction_activity} = CommonAPI.react_with_emoji(activity.id, user, "👌")

    data =
      File.read!("test/fixtures/mastodon-undo-like.json")
      |> Jason.decode!()
      |> Map.put("object", reaction_activity.data["id"])
      |> Map.put("actor", user.ap_id)

    {:ok, activity} = Transmogrifier.handle_incoming(data)

    assert activity.actor == user.ap_id
    assert activity.data["id"] == data["id"]
    assert activity.data["type"] == "Undo"
  end

  test "it returns an error for incoming unlikes wihout a like activity" do
    user = insert(:user)
    {:ok, activity} = CommonAPI.post(user, %{status: "leave a like pls"})

    data =
      File.read!("test/fixtures/mastodon-undo-like.json")
      |> Jason.decode!()
      |> Map.put("object", activity.data["object"])

    assert Transmogrifier.handle_incoming(data) == :error
  end

  test "it works for incoming unlikes with an existing like activity" do
    user = insert(:user)
    {:ok, activity} = CommonAPI.post(user, %{status: "leave a like pls"})

    like_data =
      File.read!("test/fixtures/mastodon-like.json")
      |> Jason.decode!()
      |> Map.put("object", activity.data["object"])

    _liker = insert(:user, ap_id: like_data["actor"], local: false)

    {:ok, %Activity{data: like_data, local: false}} = Transmogrifier.handle_incoming(like_data)

    data =
      File.read!("test/fixtures/mastodon-undo-like.json")
      |> Jason.decode!()
      |> Map.put("object", like_data)
      |> Map.put("actor", like_data["actor"])

    {:ok, %Activity{data: data, local: false}} = Transmogrifier.handle_incoming(data)

    assert data["actor"] == "http://mastodon.example.org/users/admin"
    assert data["type"] == "Undo"
    assert data["id"] == "http://mastodon.example.org/users/admin#likes/2/undo"
    assert data["object"] == "http://mastodon.example.org/users/admin#likes/2"

    note = Object.get_by_ap_id(like_data["object"])
    assert note.data["like_count"] == 0
    assert note.data["likes"] == []
  end

  test "it works for incoming unlikes with an existing like activity and a compact object" do
    user = insert(:user)
    {:ok, activity} = CommonAPI.post(user, %{status: "leave a like pls"})

    like_data =
      File.read!("test/fixtures/mastodon-like.json")
      |> Jason.decode!()
      |> Map.put("object", activity.data["object"])

    _liker = insert(:user, ap_id: like_data["actor"], local: false)

    {:ok, %Activity{data: like_data, local: false}} = Transmogrifier.handle_incoming(like_data)

    data =
      File.read!("test/fixtures/mastodon-undo-like.json")
      |> Jason.decode!()
      |> Map.put("object", like_data["id"])
      |> Map.put("actor", like_data["actor"])

    {:ok, %Activity{data: data, local: false}} = Transmogrifier.handle_incoming(data)

    assert data["actor"] == "http://mastodon.example.org/users/admin"
    assert data["type"] == "Undo"
    assert data["id"] == "http://mastodon.example.org/users/admin#likes/2/undo"
    assert data["object"] == "http://mastodon.example.org/users/admin#likes/2"
  end

  test "it works for incoming unannounces with an existing notice" do
    user = insert(:user)
    {:ok, activity} = CommonAPI.post(user, %{status: "hey"})

    announce_data =
      File.read!("test/fixtures/mastodon-announce.json")
      |> Jason.decode!()
      |> Map.put("object", activity.data["object"])

    _announcer = insert(:user, ap_id: announce_data["actor"], local: false)

    {:ok, %Activity{data: announce_data, local: false}} =
      Transmogrifier.handle_incoming(announce_data)

    data =
      File.read!("test/fixtures/mastodon-undo-announce.json")
      |> Jason.decode!()
      |> Map.put("object", announce_data)
      |> Map.put("actor", announce_data["actor"])

    {:ok, %Activity{data: data, local: false}} = Transmogrifier.handle_incoming(data)

    assert data["type"] == "Undo"

    assert data["object"] ==
             "http://mastodon.example.org/users/admin/statuses/99542391527669785/activity"
  end

  test "it works for incoming unfollows with an existing follow" do
    user = insert(:user)

    follow_data =
      File.read!("test/fixtures/mastodon-follow-activity.json")
      |> Jason.decode!()
      |> Map.put("object", user.ap_id)

    _follower = insert(:user, ap_id: follow_data["actor"], local: false)

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

  test "it works for incoming unblocks with an existing block" do
    user = insert(:user)

    block_data =
      File.read!("test/fixtures/mastodon-block-activity.json")
      |> Jason.decode!()
      |> Map.put("object", user.ap_id)

    _blocker = insert(:user, ap_id: block_data["actor"], local: false)

    {:ok, %Activity{data: _, local: false}} = Transmogrifier.handle_incoming(block_data)

    data =
      File.read!("test/fixtures/mastodon-unblock-activity.json")
      |> Jason.decode!()
      |> Map.put("object", block_data)

    {:ok, %Activity{data: data, local: false}} = Transmogrifier.handle_incoming(data)
    assert data["type"] == "Undo"
    assert data["object"] == block_data["id"]

    blocker = User.get_cached_by_ap_id(data["actor"])

    refute User.blocks?(blocker, user)
  end
end
