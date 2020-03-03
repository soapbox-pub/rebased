# Pleroma: A lightweight social networking server
# Copyright © 2017-2020 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.FollowingRelationshipTest do
  use Pleroma.DataCase

  alias Pleroma.FollowingRelationship
  alias Pleroma.Web.ActivityPub.InternalFetchActor
  alias Pleroma.Web.ActivityPub.Relay

  import Pleroma.Factory

  describe "following/1" do
    test "returns following addresses without internal.fetch" do
      user = insert(:user)
      fetch_actor = InternalFetchActor.get_actor()
      FollowingRelationship.follow(fetch_actor, user, "accept")
      assert FollowingRelationship.following(fetch_actor) == [user.follower_address]
    end

    test "returns following addresses without relay" do
      user = insert(:user)
      relay_actor = Relay.get_actor()
      FollowingRelationship.follow(relay_actor, user, "accept")
      assert FollowingRelationship.following(relay_actor) == [user.follower_address]
    end

    test "returns following addresses without remote user" do
      user = insert(:user)
      actor = insert(:user, local: false)
      FollowingRelationship.follow(actor, user, "accept")
      assert FollowingRelationship.following(actor) == [user.follower_address]
    end

    test "returns following addresses with local user" do
      user = insert(:user)
      actor = insert(:user, local: true)
      FollowingRelationship.follow(actor, user, "accept")

      assert FollowingRelationship.following(actor) == [
               actor.follower_address,
               user.follower_address
             ]
    end
  end
end
