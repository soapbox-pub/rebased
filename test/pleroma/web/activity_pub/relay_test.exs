# Pleroma: A lightweight social networking server
# Copyright © 2017-2022 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.ActivityPub.RelayTest do
  use Pleroma.DataCase

  alias Pleroma.Activity
  alias Pleroma.User
  alias Pleroma.Web.ActivityPub.Relay
  alias Pleroma.Web.CommonAPI

  import ExUnit.CaptureLog
  import Pleroma.Factory
  import Mock

  test "gets an actor for the relay" do
    user = Relay.get_actor()
    assert user.ap_id == "#{Pleroma.Web.Endpoint.url()}/relay"
  end

  test "relay actor is invisible" do
    user = Relay.get_actor()
    assert User.invisible?(user)
  end

  describe "follow/1" do
    test "returns errors when user not found" do
      assert capture_log(fn ->
               {:error, _} = Relay.follow("test-ap-id")
             end) =~ "Could not decode user at fetch"
    end

    test "returns activity" do
      user = insert(:user)
      service_actor = Relay.get_actor()
      assert {:ok, %Activity{} = activity} = Relay.follow(user.ap_id)
      assert activity.actor == "#{Pleroma.Web.Endpoint.url()}/relay"
      assert user.ap_id in activity.recipients
      assert activity.data["type"] == "Follow"
      assert activity.data["actor"] == service_actor.ap_id
      assert activity.data["object"] == user.ap_id
    end
  end

  describe "unfollow/1" do
    test "returns errors when user not found" do
      assert capture_log(fn ->
               {:error, _} = Relay.unfollow("test-ap-id")
             end) =~ "Could not decode user at fetch"
    end

    test "returns activity" do
      user = insert(:user)
      service_actor = Relay.get_actor()
      CommonAPI.follow(service_actor, user)
      assert "#{user.ap_id}/followers" in User.following(service_actor)
      assert {:ok, %Activity{} = activity} = Relay.unfollow(user.ap_id)
      assert activity.actor == "#{Pleroma.Web.Endpoint.url()}/relay"
      assert user.ap_id in activity.recipients
      assert activity.data["type"] == "Undo"
      assert activity.data["actor"] == service_actor.ap_id
      assert activity.data["to"] == [user.ap_id]
      refute "#{user.ap_id}/followers" in User.following(service_actor)
    end

    test "force unfollow when target service is dead" do
      user = insert(:user)
      user_ap_id = user.ap_id
      user_id = user.id

      Tesla.Mock.mock(fn %{method: :get, url: ^user_ap_id} ->
        %Tesla.Env{status: 404}
      end)

      service_actor = Relay.get_actor()
      CommonAPI.follow(service_actor, user)
      assert "#{user.ap_id}/followers" in User.following(service_actor)

      assert Pleroma.Repo.get_by(
               Pleroma.FollowingRelationship,
               follower_id: service_actor.id,
               following_id: user_id
             )

      Pleroma.Repo.delete(user)
      User.invalidate_cache(user)

      assert {:ok, %Activity{} = activity} = Relay.unfollow(user_ap_id, %{force: true})

      assert refresh_record(service_actor).following_count == 0

      refute Pleroma.Repo.get_by(
               Pleroma.FollowingRelationship,
               follower_id: service_actor.id,
               following_id: user_id
             )

      assert activity.actor == "#{Pleroma.Web.Endpoint.url()}/relay"
      assert user.ap_id in activity.recipients
      assert activity.data["type"] == "Undo"
      assert activity.data["actor"] == service_actor.ap_id
      assert activity.data["to"] == [user_ap_id]
      refute "#{user.ap_id}/followers" in User.following(service_actor)
    end
  end

  describe "publish/1" do
    setup do: clear_config([:instance, :federating])

    test "returns error when activity not `Create` type" do
      activity = insert(:like_activity)
      assert Relay.publish(activity) == {:error, "Not implemented"}
    end

    @tag capture_log: true
    test "returns error when activity not public" do
      activity = insert(:direct_note_activity)
      assert Relay.publish(activity) == {:error, false}
    end

    test "returns error when object is unknown" do
      activity =
        insert(:note_activity,
          data: %{
            "type" => "Create",
            "object" => "http://mastodon.example.org/eee/99541947525187367"
          }
        )

      Tesla.Mock.mock(fn
        %{method: :get, url: "http://mastodon.example.org/eee/99541947525187367"} ->
          %Tesla.Env{status: 500, body: ""}
      end)

      assert capture_log(fn ->
               assert Relay.publish(activity) == {:error, false}
             end) =~ "[error] error: false"
    end

    test_with_mock "returns announce activity and publish to federate",
                   Pleroma.Web.Federator,
                   [:passthrough],
                   [] do
      clear_config([:instance, :federating], true)
      service_actor = Relay.get_actor()
      note = insert(:note_activity)
      assert {:ok, %Activity{} = activity} = Relay.publish(note)
      assert activity.data["type"] == "Announce"
      assert activity.data["actor"] == service_actor.ap_id
      assert service_actor.follower_address in activity.data["to"]
      assert called(Pleroma.Web.Federator.publish(activity))
    end

    test_with_mock "returns announce activity and not publish to federate",
                   Pleroma.Web.Federator,
                   [:passthrough],
                   [] do
      clear_config([:instance, :federating], false)
      service_actor = Relay.get_actor()
      note = insert(:note_activity)
      assert {:ok, %Activity{} = activity} = Relay.publish(note)
      assert activity.data["type"] == "Announce"
      assert activity.data["actor"] == service_actor.ap_id
      refute called(Pleroma.Web.Federator.publish(activity))
    end
  end
end
