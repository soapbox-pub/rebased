# Pleroma: A lightweight social networking server
# Copyright © 2017-2019 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.ActivityPub.Transmogrifier.FollowHandlingTest do
  use Pleroma.DataCase
  alias Pleroma.Activity
  alias Pleroma.Repo
  alias Pleroma.User
  alias Pleroma.Web.ActivityPub.Transmogrifier
  alias Pleroma.Web.ActivityPub.Utils

  import Pleroma.Factory
  import Ecto.Query

  setup_all do
    Tesla.Mock.mock_global(fn env -> apply(HttpRequestMock, :request, [env]) end)
    :ok
  end

  describe "handle_incoming" do
    test "it works for osada follow request" do
      user = insert(:user)

      data =
        File.read!("test/fixtures/osada-follow-activity.json")
        |> Poison.decode!()
        |> Map.put("object", user.ap_id)

      {:ok, %Activity{data: data, local: false} = activity} = Transmogrifier.handle_incoming(data)

      assert data["actor"] == "https://apfed.club/channel/indio"
      assert data["type"] == "Follow"
      assert data["id"] == "https://apfed.club/follow/9"

      activity = Repo.get(Activity, activity.id)
      assert activity.data["state"] == "accept"
      assert User.following?(User.get_cached_by_ap_id(data["actor"]), user)
    end

    test "it works for incoming follow requests" do
      user = insert(:user)

      data =
        File.read!("test/fixtures/mastodon-follow-activity.json")
        |> Poison.decode!()
        |> Map.put("object", user.ap_id)

      {:ok, %Activity{data: data, local: false} = activity} = Transmogrifier.handle_incoming(data)

      assert data["actor"] == "http://mastodon.example.org/users/admin"
      assert data["type"] == "Follow"
      assert data["id"] == "http://mastodon.example.org/users/admin#follows/2"

      activity = Repo.get(Activity, activity.id)
      assert activity.data["state"] == "accept"
      assert User.following?(User.get_cached_by_ap_id(data["actor"]), user)
    end

    test "with locked accounts, it does not create a follow or an accept" do
      user = insert(:user, locked: true)

      data =
        File.read!("test/fixtures/mastodon-follow-activity.json")
        |> Poison.decode!()
        |> Map.put("object", user.ap_id)

      {:ok, %Activity{data: data, local: false}} = Transmogrifier.handle_incoming(data)

      assert data["state"] == "pending"

      refute User.following?(User.get_cached_by_ap_id(data["actor"]), user)

      accepts =
        from(
          a in Activity,
          where: fragment("?->>'type' = ?", a.data, "Accept")
        )
        |> Repo.all()

      assert length(accepts) == 0
    end

    test "it works for follow requests when you are already followed, creating a new accept activity" do
      # This is important because the remote might have the wrong idea about the
      # current follow status. This can lead to instance A thinking that x@A is
      # followed by y@B, but B thinks they are not. In this case, the follow can
      # never go through again because it will never get an Accept.
      user = insert(:user)

      data =
        File.read!("test/fixtures/mastodon-follow-activity.json")
        |> Poison.decode!()
        |> Map.put("object", user.ap_id)

      {:ok, %Activity{local: false}} = Transmogrifier.handle_incoming(data)

      accepts =
        from(
          a in Activity,
          where: fragment("?->>'type' = ?", a.data, "Accept")
        )
        |> Repo.all()

      assert length(accepts) == 1

      data =
        File.read!("test/fixtures/mastodon-follow-activity.json")
        |> Poison.decode!()
        |> Map.put("id", String.replace(data["id"], "2", "3"))
        |> Map.put("object", user.ap_id)

      {:ok, %Activity{local: false}} = Transmogrifier.handle_incoming(data)

      accepts =
        from(
          a in Activity,
          where: fragment("?->>'type' = ?", a.data, "Accept")
        )
        |> Repo.all()

      assert length(accepts) == 2
    end

    test "it rejects incoming follow requests from blocked users when deny_follow_blocked is enabled" do
      Pleroma.Config.put([:user, :deny_follow_blocked], true)

      user = insert(:user)
      {:ok, target} = User.get_or_fetch("http://mastodon.example.org/users/admin")

      {:ok, user} = User.block(user, target)

      data =
        File.read!("test/fixtures/mastodon-follow-activity.json")
        |> Poison.decode!()
        |> Map.put("object", user.ap_id)

      {:ok, %Activity{data: %{"id" => id}}} = Transmogrifier.handle_incoming(data)

      %Activity{} = activity = Activity.get_by_ap_id(id)

      assert activity.data["state"] == "reject"
    end

    test "it works for incoming follow requests from hubzilla" do
      user = insert(:user)

      data =
        File.read!("test/fixtures/hubzilla-follow-activity.json")
        |> Poison.decode!()
        |> Map.put("object", user.ap_id)
        |> Utils.normalize_params()

      {:ok, %Activity{data: data, local: false}} = Transmogrifier.handle_incoming(data)

      assert data["actor"] == "https://hubzilla.example.org/channel/kaniini"
      assert data["type"] == "Follow"
      assert data["id"] == "https://hubzilla.example.org/channel/kaniini#follows/2"
      assert User.following?(User.get_cached_by_ap_id(data["actor"]), user)
    end
  end
end
