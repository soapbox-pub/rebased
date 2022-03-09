# Pleroma: A lightweight social networking server
# Copyright © 2017-2022 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.ActivityPub.Transmogrifier.AcceptHandlingTest do
  use Pleroma.DataCase, async: true

  alias Pleroma.User
  alias Pleroma.Web.ActivityPub.Transmogrifier
  alias Pleroma.Web.CommonAPI

  import Pleroma.Factory

  test "it works for incoming accepts which were pre-accepted" do
    follower = insert(:user)
    followed = insert(:user)

    {:ok, follower, followed} = User.follow(follower, followed)
    assert User.following?(follower, followed) == true

    {:ok, _, _, follow_activity} = CommonAPI.follow(follower, followed)

    accept_data =
      File.read!("test/fixtures/mastodon-accept-activity.json")
      |> Jason.decode!()
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

  test "it works for incoming accepts which are referenced by IRI only" do
    follower = insert(:user)
    followed = insert(:user, is_locked: true)

    {:ok, _, _, follow_activity} = CommonAPI.follow(follower, followed)

    accept_data =
      File.read!("test/fixtures/mastodon-accept-activity.json")
      |> Jason.decode!()
      |> Map.put("actor", followed.ap_id)
      |> Map.put("object", follow_activity.data["id"])

    {:ok, activity} = Transmogrifier.handle_incoming(accept_data)
    assert activity.data["object"] == follow_activity.data["id"]

    follower = User.get_cached_by_id(follower.id)

    assert User.following?(follower, followed) == true

    follower = User.get_by_id(follower.id)
    assert follower.following_count == 1

    followed = User.get_by_id(followed.id)
    assert followed.follower_count == 1
  end

  test "it fails for incoming accepts which cannot be correlated" do
    follower = insert(:user)
    followed = insert(:user, is_locked: true)

    accept_data =
      File.read!("test/fixtures/mastodon-accept-activity.json")
      |> Jason.decode!()
      |> Map.put("actor", followed.ap_id)

    accept_data =
      Map.put(accept_data, "object", Map.put(accept_data["object"], "actor", follower.ap_id))

    {:error, _} = Transmogrifier.handle_incoming(accept_data)

    follower = User.get_cached_by_id(follower.id)

    refute User.following?(follower, followed) == true
  end
end
