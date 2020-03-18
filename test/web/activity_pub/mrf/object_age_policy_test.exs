# Pleroma: A lightweight social networking server
# Copyright © 2019 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.ActivityPub.MRF.ObjectAgePolicyTest do
  use Pleroma.DataCase
  alias Pleroma.Config
  alias Pleroma.User
  alias Pleroma.Web.ActivityPub.MRF.ObjectAgePolicy
  alias Pleroma.Web.ActivityPub.Visibility

  clear_config(:mrf_object_age,
    threshold: 172_800,
    actions: [:delist, :strip_followers]
  )

  setup_all do
    Tesla.Mock.mock_global(fn env -> apply(HttpRequestMock, :request, [env]) end)
    :ok
  end

  describe "with reject action" do
    test "it rejects an old post" do
      Config.put([:mrf_object_age, :actions], [:reject])

      data =
        File.read!("test/fixtures/mastodon-post-activity.json")
        |> Poison.decode!()

      {:reject, _} = ObjectAgePolicy.filter(data)
    end

    test "it allows a new post" do
      Config.put([:mrf_object_age, :actions], [:reject])

      data =
        File.read!("test/fixtures/mastodon-post-activity.json")
        |> Poison.decode!()
        |> Map.put("published", DateTime.utc_now() |> DateTime.to_iso8601())

      {:ok, _} = ObjectAgePolicy.filter(data)
    end
  end

  describe "with delist action" do
    test "it delists an old post" do
      Config.put([:mrf_object_age, :actions], [:delist])

      data =
        File.read!("test/fixtures/mastodon-post-activity.json")
        |> Poison.decode!()

      {:ok, _u} = User.get_or_fetch_by_ap_id(data["actor"])

      {:ok, data} = ObjectAgePolicy.filter(data)

      assert Visibility.get_visibility(%{data: data}) == "unlisted"
    end

    test "it allows a new post" do
      Config.put([:mrf_object_age, :actions], [:delist])

      data =
        File.read!("test/fixtures/mastodon-post-activity.json")
        |> Poison.decode!()
        |> Map.put("published", DateTime.utc_now() |> DateTime.to_iso8601())

      {:ok, _user} = User.get_or_fetch_by_ap_id(data["actor"])

      {:ok, ^data} = ObjectAgePolicy.filter(data)
    end
  end

  describe "with strip_followers action" do
    test "it strips followers collections from an old post" do
      Config.put([:mrf_object_age, :actions], [:strip_followers])

      data =
        File.read!("test/fixtures/mastodon-post-activity.json")
        |> Poison.decode!()

      {:ok, user} = User.get_or_fetch_by_ap_id(data["actor"])

      {:ok, data} = ObjectAgePolicy.filter(data)

      refute user.follower_address in data["to"]
      refute user.follower_address in data["cc"]
    end

    test "it allows a new post" do
      Config.put([:mrf_object_age, :actions], [:strip_followers])

      data =
        File.read!("test/fixtures/mastodon-post-activity.json")
        |> Poison.decode!()
        |> Map.put("published", DateTime.utc_now() |> DateTime.to_iso8601())

      {:ok, _u} = User.get_or_fetch_by_ap_id(data["actor"])

      {:ok, ^data} = ObjectAgePolicy.filter(data)
    end
  end
end
