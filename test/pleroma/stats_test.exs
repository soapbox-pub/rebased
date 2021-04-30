# Pleroma: A lightweight social networking server
# Copyright © 2017-2021 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.StatsTest do
  use Pleroma.DataCase, async: true

  import Pleroma.Factory

  alias Pleroma.Stats
  alias Pleroma.Web.CommonAPI

  describe "user count" do
    test "it ignores internal users" do
      _user = insert(:user, local: true)
      _internal = insert(:user, local: true, nickname: nil)
      _internal = Pleroma.Web.ActivityPub.Relay.get_actor()

      assert match?(%{stats: %{user_count: 1}}, Stats.calculate_stat_data())
    end
  end

  describe "status visibility sum count" do
    test "on new status" do
      instance2 = "instance2.tld"
      user = insert(:user)
      other_user = insert(:user, %{ap_id: "https://#{instance2}/@actor"})

      CommonAPI.post(user, %{visibility: "public", status: "hey"})

      Enum.each(0..1, fn _ ->
        CommonAPI.post(user, %{
          visibility: "unlisted",
          status: "hey"
        })
      end)

      Enum.each(0..2, fn _ ->
        CommonAPI.post(user, %{
          visibility: "direct",
          status: "hey @#{other_user.nickname}"
        })
      end)

      Enum.each(0..3, fn _ ->
        CommonAPI.post(user, %{
          visibility: "private",
          status: "hey"
        })
      end)

      assert %{"direct" => 3, "private" => 4, "public" => 1, "unlisted" => 2} =
               Stats.get_status_visibility_count()
    end

    test "on status delete" do
      user = insert(:user)
      {:ok, activity} = CommonAPI.post(user, %{visibility: "public", status: "hey"})
      assert %{"public" => 1} = Stats.get_status_visibility_count()
      CommonAPI.delete(activity.id, user)
      assert %{"public" => 0} = Stats.get_status_visibility_count()
    end

    test "on status visibility update" do
      user = insert(:user)
      {:ok, activity} = CommonAPI.post(user, %{visibility: "public", status: "hey"})
      assert %{"public" => 1, "private" => 0} = Stats.get_status_visibility_count()
      {:ok, _} = CommonAPI.update_activity_scope(activity.id, %{visibility: "private"})
      assert %{"public" => 0, "private" => 1} = Stats.get_status_visibility_count()
    end

    test "doesn't count unrelated activities" do
      user = insert(:user)
      other_user = insert(:user)
      {:ok, activity} = CommonAPI.post(user, %{visibility: "public", status: "hey"})
      _ = CommonAPI.follow(user, other_user)
      CommonAPI.favorite(other_user, activity.id)
      CommonAPI.repeat(activity.id, other_user)

      assert %{"direct" => 0, "private" => 0, "public" => 1, "unlisted" => 0} =
               Stats.get_status_visibility_count()
    end
  end

  describe "status visibility by instance count" do
    test "single instance" do
      local_instance = Pleroma.Web.Endpoint.url() |> String.split("//") |> Enum.at(1)
      instance2 = "instance2.tld"
      user1 = insert(:user)
      user2 = insert(:user, %{ap_id: "https://#{instance2}/@actor"})

      CommonAPI.post(user1, %{visibility: "public", status: "hey"})

      Enum.each(1..5, fn _ ->
        CommonAPI.post(user1, %{
          visibility: "unlisted",
          status: "hey"
        })
      end)

      Enum.each(1..10, fn _ ->
        CommonAPI.post(user1, %{
          visibility: "direct",
          status: "hey @#{user2.nickname}"
        })
      end)

      Enum.each(1..20, fn _ ->
        CommonAPI.post(user2, %{
          visibility: "private",
          status: "hey"
        })
      end)

      assert %{"direct" => 10, "private" => 0, "public" => 1, "unlisted" => 5} =
               Stats.get_status_visibility_count(local_instance)

      assert %{"direct" => 0, "private" => 20, "public" => 0, "unlisted" => 0} =
               Stats.get_status_visibility_count(instance2)
    end
  end
end
