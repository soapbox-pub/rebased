# Pleroma: A lightweight social networking server
# Copyright © 2017-2022 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Mix.Tasks.Pleroma.RelayTest do
  alias Pleroma.Activity
  alias Pleroma.User
  alias Pleroma.Web.ActivityPub.ActivityPub
  alias Pleroma.Web.ActivityPub.Relay
  alias Pleroma.Web.ActivityPub.Utils
  use Pleroma.DataCase

  import Pleroma.Factory

  setup_all do
    Tesla.Mock.mock_global(fn env -> apply(HttpRequestMock, :request, [env]) end)

    Mix.shell(Mix.Shell.Process)

    on_exit(fn ->
      Mix.shell(Mix.Shell.IO)
    end)

    :ok
  end

  describe "running follow" do
    test "relay is followed" do
      target_instance = "http://mastodon.example.org/users/admin"

      Mix.Tasks.Pleroma.Relay.run(["follow", target_instance])

      local_user = Relay.get_actor()
      assert local_user.ap_id =~ "/relay"

      target_user = User.get_cached_by_ap_id(target_instance)
      refute target_user.local

      activity = Utils.fetch_latest_follow(local_user, target_user)
      assert activity.data["type"] == "Follow"
      assert activity.data["actor"] == local_user.ap_id
      assert activity.data["object"] == target_user.ap_id

      :ok = Mix.Tasks.Pleroma.Relay.run(["list"])

      assert_receive {:mix_shell, :info,
                      [
                        "http://mastodon.example.org/users/admin - no Accept received (relay didn't follow back)"
                      ]}
    end
  end

  describe "running unfollow" do
    test "relay is unfollowed" do
      user = insert(:user)
      target_instance = user.ap_id

      Mix.Tasks.Pleroma.Relay.run(["follow", target_instance])

      %User{ap_id: follower_id} = local_user = Relay.get_actor()
      target_user = User.get_cached_by_ap_id(target_instance)
      follow_activity = Utils.fetch_latest_follow(local_user, target_user)
      User.follow(local_user, target_user)
      assert "#{target_instance}/followers" in User.following(local_user)
      Mix.Tasks.Pleroma.Relay.run(["unfollow", target_instance])

      cancelled_activity = Activity.get_by_ap_id(follow_activity.data["id"])
      assert cancelled_activity.data["state"] == "cancelled"

      [undo_activity] =
        ActivityPub.fetch_activities([], %{
          type: "Undo",
          actor_id: follower_id,
          limit: 1,
          skip_preload: true,
          invisible_actors: true
        })

      assert undo_activity.data["type"] == "Undo"
      assert undo_activity.data["actor"] == local_user.ap_id
      assert undo_activity.data["object"]["id"] == cancelled_activity.data["id"]
      refute "#{target_instance}/followers" in User.following(local_user)
    end

    test "unfollow when relay is dead" do
      user = insert(:user)
      target_instance = user.ap_id

      Mix.Tasks.Pleroma.Relay.run(["follow", target_instance])

      %User{ap_id: follower_id} = local_user = Relay.get_actor()
      target_user = User.get_cached_by_ap_id(target_instance)
      follow_activity = Utils.fetch_latest_follow(local_user, target_user)
      User.follow(local_user, target_user)

      assert "#{target_instance}/followers" in User.following(local_user)

      Tesla.Mock.mock(fn %{method: :get, url: ^target_instance} ->
        %Tesla.Env{status: 404}
      end)

      Pleroma.Repo.delete(user)
      User.invalidate_cache(user)

      Mix.Tasks.Pleroma.Relay.run(["unfollow", target_instance])

      cancelled_activity = Activity.get_by_ap_id(follow_activity.data["id"])
      assert cancelled_activity.data["state"] == "accept"

      assert [] ==
               ActivityPub.fetch_activities(
                 [],
                 %{
                   type: "Undo",
                   actor_id: follower_id,
                   skip_preload: true,
                   invisible_actors: true
                 }
               )
    end

    test "force unfollow when relay is dead" do
      user = insert(:user)
      target_instance = user.ap_id

      Mix.Tasks.Pleroma.Relay.run(["follow", target_instance])

      %User{ap_id: follower_id} = local_user = Relay.get_actor()
      target_user = User.get_cached_by_ap_id(target_instance)
      follow_activity = Utils.fetch_latest_follow(local_user, target_user)
      User.follow(local_user, target_user)

      assert "#{target_instance}/followers" in User.following(local_user)

      Tesla.Mock.mock(fn %{method: :get, url: ^target_instance} ->
        %Tesla.Env{status: 404}
      end)

      Pleroma.Repo.delete(user)
      User.invalidate_cache(user)

      Mix.Tasks.Pleroma.Relay.run(["unfollow", target_instance, "--force"])

      cancelled_activity = Activity.get_by_ap_id(follow_activity.data["id"])
      assert cancelled_activity.data["state"] == "cancelled"

      [undo_activity] =
        ActivityPub.fetch_activities(
          [],
          %{type: "Undo", actor_id: follower_id, skip_preload: true, invisible_actors: true}
        )

      assert undo_activity.data["type"] == "Undo"
      assert undo_activity.data["actor"] == local_user.ap_id
      assert undo_activity.data["object"]["id"] == cancelled_activity.data["id"]
      refute "#{target_instance}/followers" in User.following(local_user)
    end
  end

  describe "mix pleroma.relay list" do
    test "Prints relay subscription list" do
      :ok = Mix.Tasks.Pleroma.Relay.run(["list"])

      refute_receive {:mix_shell, :info, _}

      relay_user = Relay.get_actor()

      ["http://mastodon.example.org/users/admin", "https://mstdn.io/users/mayuutann"]
      |> Enum.each(fn ap_id ->
        {:ok, user} = User.get_or_fetch_by_ap_id(ap_id)
        User.follow(relay_user, user)
      end)

      :ok = Mix.Tasks.Pleroma.Relay.run(["list"])

      assert_receive {:mix_shell, :info, ["https://mstdn.io/users/mayuutann"]}
      assert_receive {:mix_shell, :info, ["http://mastodon.example.org/users/admin"]}
    end
  end
end
