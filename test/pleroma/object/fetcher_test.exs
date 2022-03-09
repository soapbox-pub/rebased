# Pleroma: A lightweight social networking server
# Copyright © 2017-2022 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Object.FetcherTest do
  use Pleroma.DataCase

  alias Pleroma.Activity
  alias Pleroma.Object
  alias Pleroma.Object.Fetcher

  import Mock
  import Tesla.Mock

  setup do
    mock(fn
      %{method: :get, url: "https://mastodon.example.org/users/userisgone"} ->
        %Tesla.Env{status: 410}

      %{method: :get, url: "https://mastodon.example.org/users/userisgone404"} ->
        %Tesla.Env{status: 404}

      %{
        method: :get,
        url:
          "https://patch.cx/media/03ca3c8b4ac3ddd08bf0f84be7885f2f88de0f709112131a22d83650819e36c2.json"
      } ->
        %Tesla.Env{
          status: 200,
          headers: [{"content-type", "application/json"}],
          body: File.read!("test/fixtures/spoofed-object.json")
        }

      env ->
        apply(HttpRequestMock, :request, [env])
    end)

    :ok
  end

  describe "error cases" do
    setup do
      mock(fn
        %{method: :get, url: "https://social.sakamoto.gq/notice/9wTkLEnuq47B25EehM"} ->
          %Tesla.Env{
            status: 200,
            body: File.read!("test/fixtures/fetch_mocks/9wTkLEnuq47B25EehM.json"),
            headers: HttpRequestMock.activitypub_object_headers()
          }

        %{method: :get, url: "https://social.sakamoto.gq/users/eal"} ->
          %Tesla.Env{
            status: 200,
            body: File.read!("test/fixtures/fetch_mocks/eal.json"),
            headers: HttpRequestMock.activitypub_object_headers()
          }

        %{method: :get, url: "https://busshi.moe/users/tuxcrafting/statuses/104410921027210069"} ->
          %Tesla.Env{
            status: 200,
            body: File.read!("test/fixtures/fetch_mocks/104410921027210069.json"),
            headers: HttpRequestMock.activitypub_object_headers()
          }

        %{method: :get, url: "https://busshi.moe/users/tuxcrafting"} ->
          %Tesla.Env{
            status: 500
          }

        %{
          method: :get,
          url: "https://stereophonic.space/objects/02997b83-3ea7-4b63-94af-ef3aa2d4ed17"
        } ->
          %Tesla.Env{
            status: 500
          }
      end)

      :ok
    end

    @tag capture_log: true
    test "it works when fetching the OP actor errors out" do
      # Here we simulate a case where the author of the OP can't be read
      assert {:ok, _} =
               Fetcher.fetch_object_from_id(
                 "https://social.sakamoto.gq/notice/9wTkLEnuq47B25EehM"
               )
    end
  end

  describe "max thread distance restriction" do
    @ap_id "http://mastodon.example.org/@admin/99541947525187367"
    setup do: clear_config([:instance, :federation_incoming_replies_max_depth])

    test "it returns thread depth exceeded error if thread depth is exceeded" do
      clear_config([:instance, :federation_incoming_replies_max_depth], 0)

      assert {:error, "Max thread distance exceeded."} =
               Fetcher.fetch_object_from_id(@ap_id, depth: 1)
    end

    test "it fetches object if max thread depth is restricted to 0 and depth is not specified" do
      clear_config([:instance, :federation_incoming_replies_max_depth], 0)

      assert {:ok, _} = Fetcher.fetch_object_from_id(@ap_id)
    end

    test "it fetches object if requested depth does not exceed max thread depth" do
      clear_config([:instance, :federation_incoming_replies_max_depth], 10)

      assert {:ok, _} = Fetcher.fetch_object_from_id(@ap_id, depth: 10)
    end
  end

  describe "actor origin containment" do
    test "it rejects objects with a bogus origin" do
      {:error, _} = Fetcher.fetch_object_from_id("https://info.pleroma.site/activity.json")
    end

    test "it rejects objects when attributedTo is wrong (variant 1)" do
      {:error, _} = Fetcher.fetch_object_from_id("https://info.pleroma.site/activity2.json")
    end

    test "it rejects objects when attributedTo is wrong (variant 2)" do
      {:error, _} = Fetcher.fetch_object_from_id("https://info.pleroma.site/activity3.json")
    end
  end

  describe "fetching an object" do
    test "it fetches an object" do
      {:ok, object} =
        Fetcher.fetch_object_from_id("http://mastodon.example.org/@admin/99541947525187367")

      assert _activity = Activity.get_create_by_object_ap_id(object.data["id"])

      {:ok, object_again} =
        Fetcher.fetch_object_from_id("http://mastodon.example.org/@admin/99541947525187367")

      assert [attachment] = object.data["attachment"]
      assert is_list(attachment["url"])

      assert object == object_again
    end

    test "Return MRF reason when fetched status is rejected by one" do
      clear_config([:mrf_keyword, :reject], ["yeah"])
      clear_config([:mrf, :policies], [Pleroma.Web.ActivityPub.MRF.KeywordPolicy])

      assert {:reject, "[KeywordPolicy] Matches with rejected keyword"} ==
               Fetcher.fetch_object_from_id(
                 "http://mastodon.example.org/@admin/99541947525187367"
               )
    end

    test "it does not fetch a spoofed object uploaded on an instance as an attachment" do
      assert {:error, _} =
               Fetcher.fetch_object_from_id(
                 "https://patch.cx/media/03ca3c8b4ac3ddd08bf0f84be7885f2f88de0f709112131a22d83650819e36c2.json"
               )
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

    test "it can fetch Mobilizon events" do
      {:ok, object} =
        Fetcher.fetch_object_from_id(
          "https://mobilizon.org/events/252d5816-00a3-4a89-a66f-15bf65c33e39"
        )

      assert object
    end

    test "it can fetch wedistribute articles" do
      {:ok, object} =
        Fetcher.fetch_object_from_id("https://wedistribute.org/wp-json/pterotype/v1/object/85810")

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

    test "it can fetch pleroma polls with attachments" do
      {:ok, object} =
        Fetcher.fetch_object_from_id("https://patch.cx/objects/tesla_mock/poll_attachment")

      assert object
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

  describe "signed fetches" do
    setup do: clear_config([:activitypub, :sign_object_fetches])

    test_with_mock "it signs fetches when configured to do so",
                   Pleroma.Signature,
                   [:passthrough],
                   [] do
      clear_config([:activitypub, :sign_object_fetches], true)

      Fetcher.fetch_object_from_id("http://mastodon.example.org/@admin/99541947525187367")

      assert called(Pleroma.Signature.sign(:_, :_))
    end

    test_with_mock "it doesn't sign fetches when not configured to do so",
                   Pleroma.Signature,
                   [:passthrough],
                   [] do
      clear_config([:activitypub, :sign_object_fetches], false)

      Fetcher.fetch_object_from_id("http://mastodon.example.org/@admin/99541947525187367")

      refute called(Pleroma.Signature.sign(:_, :_))
    end
  end
end
