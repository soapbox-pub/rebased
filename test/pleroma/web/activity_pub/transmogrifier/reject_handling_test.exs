# Pleroma: A lightweight social networking server
# Copyright © 2017-2021 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.ActivityPub.Transmogrifier.RejectHandlingTest do
  use Pleroma.DataCase, async: true

  alias Pleroma.Activity
  alias Pleroma.User
  alias Pleroma.Web.ActivityPub.Transmogrifier
  alias Pleroma.Web.CommonAPI

  import Pleroma.Factory

  test "it fails for incoming rejects which cannot be correlated" do
    follower = insert(:user)
    followed = insert(:user, is_locked: true)

    accept_data =
      File.read!("test/fixtures/mastodon-reject-activity.json")
      |> Jason.decode!()
      |> Map.put("actor", followed.ap_id)

    accept_data =
      Map.put(accept_data, "object", Map.put(accept_data["object"], "actor", follower.ap_id))

    {:error, _} = Transmogrifier.handle_incoming(accept_data)

    follower = User.get_cached_by_id(follower.id)

    refute User.following?(follower, followed) == true
  end

  test "it works for incoming rejects which are referenced by IRI only" do
    follower = insert(:user)
    followed = insert(:user, is_locked: true)

    {:ok, follower, followed} = User.follow(follower, followed)
    {:ok, _, _, follow_activity} = CommonAPI.follow(follower, followed)

    assert User.following?(follower, followed) == true

    reject_data =
      File.read!("test/fixtures/mastodon-reject-activity.json")
      |> Jason.decode!()
      |> Map.put("actor", followed.ap_id)
      |> Map.put("object", follow_activity.data["id"])

    {:ok, %Activity{data: _}} = Transmogrifier.handle_incoming(reject_data)

    follower = User.get_cached_by_id(follower.id)

    assert User.following?(follower, followed) == false
  end

  test "it rejects activities without a valid ID" do
    user = insert(:user)

    data =
      File.read!("test/fixtures/mastodon-follow-activity.json")
      |> Jason.decode!()
      |> Map.put("object", user.ap_id)
      |> Map.put("id", "")

    :error = Transmogrifier.handle_incoming(data)
  end
end
