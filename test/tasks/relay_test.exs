defmodule Mix.Tasks.Pleroma.RelayTest do
  alias Pleroma.Activity
  alias Pleroma.Web.ActivityPub.{ActivityPub, Relay, Utils}
  alias Pleroma.User
  use Pleroma.DataCase

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

      target_user = User.get_by_ap_id(target_instance)
      refute target_user.local

      activity = Utils.fetch_latest_follow(local_user, target_user)
      assert activity.data["type"] == "Follow"
      assert activity.data["actor"] == local_user.ap_id
      assert activity.data["object"] == target_user.ap_id
    end
  end

  describe "running unfollow" do
    test "relay is unfollowed" do
      target_instance = "http://mastodon.example.org/users/admin"

      Mix.Tasks.Pleroma.Relay.run(["follow", target_instance])

      %User{ap_id: follower_id} = local_user = Relay.get_actor()
      target_user = User.get_by_ap_id(target_instance)
      follow_activity = Utils.fetch_latest_follow(local_user, target_user)

      Mix.Tasks.Pleroma.Relay.run(["unfollow", target_instance])

      cancelled_activity = Activity.get_by_ap_id(follow_activity.data["id"])
      assert cancelled_activity.data["state"] == "cancelled"

      [undo_activity] =
        ActivityPub.fetch_activities([], %{
          "type" => "Undo",
          "actor_id" => follower_id,
          "limit" => 1
        })

      assert undo_activity.data["type"] == "Undo"
      assert undo_activity.data["actor"] == local_user.ap_id
      assert undo_activity.data["object"] == cancelled_activity.data
    end
  end
end
