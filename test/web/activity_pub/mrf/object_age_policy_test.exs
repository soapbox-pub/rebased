# Pleroma: A lightweight social networking server
# Copyright © 2019 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.ActivityPub.MRF.ObjectAgePolicyTest do
  use Pleroma.DataCase
  alias Pleroma.Config
  alias Pleroma.User
  alias Pleroma.Web.ActivityPub.MRF.ObjectAgePolicy
  alias Pleroma.Web.ActivityPub.Visibility

  clear_config([:mrf_object_age]) do
    Config.put(:mrf_object_age,
      threshold: 172_800,
      actions: [:delist, :strip_followers]
    )
  end

  setup_all do
    Tesla.Mock.mock_global(fn env -> apply(HttpRequestMock, :request, [env]) end)
    :ok
  end

  defp get_old_message do
    File.read!("test/fixtures/mastodon-post-activity.json")
    |> Poison.decode!()
  end

  defp get_new_message do
    old_message = get_old_message()

    new_object =
      old_message
      |> Map.get("object")
      |> Map.put("published", DateTime.utc_now() |> DateTime.to_iso8601())

    old_message
    |> Map.put("object", new_object)
  end

  describe "with reject action" do
    test "it rejects an old post" do
      Config.put([:mrf_object_age, :actions], [:reject])

      data = get_old_message()

      assert match?({:reject, _}, ObjectAgePolicy.filter(data))
    end

    test "it allows a new post" do
      Config.put([:mrf_object_age, :actions], [:reject])

      data = get_new_message()

      assert match?({:ok, _}, ObjectAgePolicy.filter(data))
    end
  end

  describe "with delist action" do
    test "it delists an old post" do
      Config.put([:mrf_object_age, :actions], [:delist])

      data = get_old_message()

      {:ok, _u} = User.get_or_fetch_by_ap_id(data["actor"])

      {:ok, data} = ObjectAgePolicy.filter(data)

      assert Visibility.get_visibility(%{data: data}) == "unlisted"
    end

    test "it allows a new post" do
      Config.put([:mrf_object_age, :actions], [:delist])

      data = get_new_message()

      {:ok, _user} = User.get_or_fetch_by_ap_id(data["actor"])

      assert match?({:ok, ^data}, ObjectAgePolicy.filter(data))
    end
  end

  describe "with strip_followers action" do
    test "it strips followers collections from an old post" do
      Config.put([:mrf_object_age, :actions], [:strip_followers])

      data = get_old_message()

      {:ok, user} = User.get_or_fetch_by_ap_id(data["actor"])

      {:ok, data} = ObjectAgePolicy.filter(data)

      refute user.follower_address in data["to"]
      refute user.follower_address in data["cc"]
    end

    test "it allows a new post" do
      Config.put([:mrf_object_age, :actions], [:strip_followers])

      data = get_new_message()

      {:ok, _u} = User.get_or_fetch_by_ap_id(data["actor"])

      assert match?({:ok, ^data}, ObjectAgePolicy.filter(data))
    end
  end
end
