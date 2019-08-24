# Pleroma: A lightweight social networking server
# Copyright © 2017-2019 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.RichMedia.HelpersTest do
  use Pleroma.DataCase

  alias Pleroma.Config
  alias Pleroma.Object
  alias Pleroma.Web.CommonAPI
  alias Pleroma.Web.RichMedia.Helpers

  import Pleroma.Factory
  import Tesla.Mock

  setup do
    mock(fn env -> apply(HttpRequestMock, :request, [env]) end)

    :ok
  end

  clear_config([:rich_media, :enabled])

  test "refuses to crawl incomplete URLs" do
    user = insert(:user)

    {:ok, activity} =
      CommonAPI.post(user, %{
        "status" => "[test](example.com/ogp)",
        "content_type" => "text/markdown"
      })

    Config.put([:rich_media, :enabled], true)

    assert %{} == Pleroma.Web.RichMedia.Helpers.fetch_data_for_activity(activity)
  end

  test "refuses to crawl malformed URLs" do
    user = insert(:user)

    {:ok, activity} =
      CommonAPI.post(user, %{
        "status" => "[test](example.com[]/ogp)",
        "content_type" => "text/markdown"
      })

    Config.put([:rich_media, :enabled], true)

    assert %{} == Pleroma.Web.RichMedia.Helpers.fetch_data_for_activity(activity)
  end

  test "crawls valid, complete URLs" do
    user = insert(:user)

    {:ok, activity} =
      CommonAPI.post(user, %{
        "status" => "[test](https://example.com/ogp)",
        "content_type" => "text/markdown"
      })

    Config.put([:rich_media, :enabled], true)

    assert %{page_url: "https://example.com/ogp", rich_media: _} =
             Pleroma.Web.RichMedia.Helpers.fetch_data_for_activity(activity)
  end

  test "refuses to crawl URLs from posts marked sensitive" do
    user = insert(:user)

    {:ok, activity} =
      CommonAPI.post(user, %{
        "status" => "http://example.com/ogp",
        "sensitive" => true
      })

    %Object{} = object = Object.normalize(activity)

    assert object.data["sensitive"]

    Config.put([:rich_media, :enabled], true)

    assert %{} = Pleroma.Web.RichMedia.Helpers.fetch_data_for_activity(activity)
  end

  test "refuses to crawl URLs from posts tagged NSFW" do
    user = insert(:user)

    {:ok, activity} =
      CommonAPI.post(user, %{
        "status" => "http://example.com/ogp #nsfw"
      })

    %Object{} = object = Object.normalize(activity)

    assert object.data["sensitive"]

    Config.put([:rich_media, :enabled], true)

    assert %{} = Pleroma.Web.RichMedia.Helpers.fetch_data_for_activity(activity)
  end

  test "refuses to crawl URLs of private network from posts" do
    user = insert(:user)

    {:ok, activity} =
      CommonAPI.post(user, %{"status" => "http://127.0.0.1:4000/notice/9kCP7VNyPJXFOXDrgO"})

    {:ok, activity2} = CommonAPI.post(user, %{"status" => "https://10.111.10.1/notice/9kCP7V"})
    {:ok, activity3} = CommonAPI.post(user, %{"status" => "https://172.16.32.40/notice/9kCP7V"})
    {:ok, activity4} = CommonAPI.post(user, %{"status" => "https://192.168.10.40/notice/9kCP7V"})
    {:ok, activity5} = CommonAPI.post(user, %{"status" => "https://pleroma.local/notice/9kCP7V"})

    Config.put([:rich_media, :enabled], true)

    assert %{} = Helpers.fetch_data_for_activity(activity)
    assert %{} = Helpers.fetch_data_for_activity(activity2)
    assert %{} = Helpers.fetch_data_for_activity(activity3)
    assert %{} = Helpers.fetch_data_for_activity(activity4)
    assert %{} = Helpers.fetch_data_for_activity(activity5)
  end
end
