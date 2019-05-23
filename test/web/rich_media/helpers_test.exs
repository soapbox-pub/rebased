defmodule Pleroma.Web.RichMedia.HelpersTest do
  use Pleroma.DataCase

  alias Pleroma.Object
  alias Pleroma.Web.CommonAPI

  import Pleroma.Factory
  import Tesla.Mock

  setup do
    mock(fn env -> apply(HttpRequestMock, :request, [env]) end)
    :ok
  end

  test "refuses to crawl incomplete URLs" do
    user = insert(:user)

    {:ok, activity} =
      CommonAPI.post(user, %{
        "status" => "[test](example.com/ogp)",
        "content_type" => "text/markdown"
      })

    Pleroma.Config.put([:rich_media, :enabled], true)

    assert %{} == Pleroma.Web.RichMedia.Helpers.fetch_data_for_activity(activity)

    Pleroma.Config.put([:rich_media, :enabled], false)
  end

  test "refuses to crawl malformed URLs" do
    user = insert(:user)

    {:ok, activity} =
      CommonAPI.post(user, %{
        "status" => "[test](example.com[]/ogp)",
        "content_type" => "text/markdown"
      })

    Pleroma.Config.put([:rich_media, :enabled], true)

    assert %{} == Pleroma.Web.RichMedia.Helpers.fetch_data_for_activity(activity)

    Pleroma.Config.put([:rich_media, :enabled], false)
  end

  test "crawls valid, complete URLs" do
    user = insert(:user)

    {:ok, activity} =
      CommonAPI.post(user, %{
        "status" => "[test](http://example.com/ogp)",
        "content_type" => "text/markdown"
      })

    Pleroma.Config.put([:rich_media, :enabled], true)

    assert %{page_url: "http://example.com/ogp", rich_media: _} =
             Pleroma.Web.RichMedia.Helpers.fetch_data_for_activity(activity)

    Pleroma.Config.put([:rich_media, :enabled], false)
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

    Pleroma.Config.put([:rich_media, :enabled], true)

    assert %{} = Pleroma.Web.RichMedia.Helpers.fetch_data_for_activity(activity)

    Pleroma.Config.put([:rich_media, :enabled], false)
  end

  test "refuses to crawl URLs from posts tagged NSFW" do
    user = insert(:user)

    {:ok, activity} =
      CommonAPI.post(user, %{
        "status" => "http://example.com/ogp #nsfw"
      })

    %Object{} = object = Object.normalize(activity)

    assert object.data["sensitive"]

    Pleroma.Config.put([:rich_media, :enabled], true)

    assert %{} = Pleroma.Web.RichMedia.Helpers.fetch_data_for_activity(activity)

    Pleroma.Config.put([:rich_media, :enabled], false)
  end
end
