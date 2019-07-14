# Pleroma: A lightweight social networking server
# Copyright © 2017-2019 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Object.FetcherTest do
  use Pleroma.DataCase

  alias Pleroma.Activity
  alias Pleroma.Object
  alias Pleroma.Object.Fetcher
  import Tesla.Mock
  import Mock

  setup do
    mock(fn
      %{method: :get, url: "https://mastodon.example.org/users/userisgone"} ->
        %Tesla.Env{status: 410}

      %{method: :get, url: "https://mastodon.example.org/users/userisgone404"} ->
        %Tesla.Env{status: 404}

      env ->
        apply(HttpRequestMock, :request, [env])
    end)

    :ok
  end

  describe "actor origin containment" do
    test_with_mock "it rejects objects with a bogus origin",
                   Pleroma.Web.OStatus,
                   [:passthrough],
                   [] do
      {:error, _} = Fetcher.fetch_object_from_id("https://info.pleroma.site/activity.json")

      refute called(Pleroma.Web.OStatus.fetch_activity_from_url(:_))
    end

    test_with_mock "it rejects objects when attributedTo is wrong (variant 1)",
                   Pleroma.Web.OStatus,
                   [:passthrough],
                   [] do
      {:error, _} = Fetcher.fetch_object_from_id("https://info.pleroma.site/activity2.json")

      refute called(Pleroma.Web.OStatus.fetch_activity_from_url(:_))
    end

    test_with_mock "it rejects objects when attributedTo is wrong (variant 2)",
                   Pleroma.Web.OStatus,
                   [:passthrough],
                   [] do
      {:error, _} = Fetcher.fetch_object_from_id("https://info.pleroma.site/activity3.json")

      refute called(Pleroma.Web.OStatus.fetch_activity_from_url(:_))
    end
  end

  describe "fetching an object" do
    test "it fetches an object" do
      {:ok, object} =
        Fetcher.fetch_object_from_id("http://mastodon.example.org/@admin/99541947525187367")

      assert activity = Activity.get_create_by_object_ap_id(object.data["id"])
      assert activity.data["id"]

      {:ok, object_again} =
        Fetcher.fetch_object_from_id("http://mastodon.example.org/@admin/99541947525187367")

      assert [attachment] = object.data["attachment"]
      assert is_list(attachment["url"])

      assert object == object_again
    end

    test "it works with objects only available via Ostatus" do
      {:ok, object} = Fetcher.fetch_object_from_id("https://shitposter.club/notice/2827873")
      assert activity = Activity.get_create_by_object_ap_id(object.data["id"])
      assert activity.data["id"]

      {:ok, object_again} = Fetcher.fetch_object_from_id("https://shitposter.club/notice/2827873")

      assert object == object_again
    end

    test "it correctly stitches up conversations between ostatus and ap" do
      last = "https://mstdn.io/users/mayuutann/statuses/99568293732299394"
      {:ok, object} = Fetcher.fetch_object_from_id(last)

      object = Object.get_by_ap_id(object.data["inReplyTo"])
      assert object
    end
  end

  describe "implementation quirks" do
    test "it can fetch plume articles" do
      {:ok, object} =
        Fetcher.fetch_object_from_id(
          "https://baptiste.gelez.xyz/~/PlumeDevelopment/this-month-in-plume-june-2018/"
        )

      assert object
    end

    test "it can fetch peertube videos" do
      {:ok, object} =
        Fetcher.fetch_object_from_id(
          "https://peertube.moe/videos/watch/df5f464b-be8d-46fb-ad81-2d4c2d1630e3"
        )

      assert object
    end

    test "all objects with fake directions are rejected by the object fetcher" do
      assert {:error, _} =
               Fetcher.fetch_and_contain_remote_object_from_id(
                 "https://info.pleroma.site/activity4.json"
               )
    end

    test "handle HTTP 410 Gone response" do
      assert {:error, "Object has been deleted"} ==
               Fetcher.fetch_and_contain_remote_object_from_id(
                 "https://mastodon.example.org/users/userisgone"
               )
    end

    test "handle HTTP 404 response" do
      assert {:error, "Object has been deleted"} ==
               Fetcher.fetch_and_contain_remote_object_from_id(
                 "https://mastodon.example.org/users/userisgone404"
               )
    end
  end

  describe "pruning" do
    test "it can refetch pruned objects" do
      object_id = "http://mastodon.example.org/@admin/99541947525187367"

      {:ok, object} = Fetcher.fetch_object_from_id(object_id)

      assert object

      {:ok, _object} = Object.prune(object)

      refute Object.get_by_ap_id(object_id)

      {:ok, %Object{} = object_two} = Fetcher.fetch_object_from_id(object_id)

      assert object.data["id"] == object_two.data["id"]
      assert object.id != object_two.id
    end
  end
end
