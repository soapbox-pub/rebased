# Pleroma: A lightweight social networking server
# Copyright © 2017-2021 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.ActivityPub.Transmogrifier.BlockHandlingTest do
  use Pleroma.DataCase, async: true

  alias Pleroma.Activity
  alias Pleroma.User
  alias Pleroma.Web.ActivityPub.Transmogrifier

  import Pleroma.Factory

  test "it works for incoming blocks" do
    user = insert(:user)

    data =
      File.read!("test/fixtures/mastodon-block-activity.json")
      |> Jason.decode!()
      |> Map.put("object", user.ap_id)

    blocker = insert(:user, ap_id: data["actor"])

    {:ok, %Activity{data: data, local: false}} = Transmogrifier.handle_incoming(data)

    assert data["type"] == "Block"
    assert data["object"] == user.ap_id
    assert data["actor"] == "http://mastodon.example.org/users/admin"

    assert User.blocks?(blocker, user)
  end

  test "incoming blocks successfully tear down any follow relationship" do
    blocker = insert(:user)
    blocked = insert(:user)

    data =
      File.read!("test/fixtures/mastodon-block-activity.json")
      |> Jason.decode!()
      |> Map.put("object", blocked.ap_id)
      |> Map.put("actor", blocker.ap_id)

    {:ok, blocker, blocked} = User.follow(blocker, blocked)
    {:ok, blocked, blocker} = User.follow(blocked, blocker)

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
end
