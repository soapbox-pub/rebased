# Pleroma: A lightweight social networking server
# Copyright © 2017-2022 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.RichMedia.ParserTest do
  use Pleroma.DataCase

  alias Pleroma.Web.RichMedia.Parser

  import Tesla.Mock

  setup do
    mock_global(fn env -> apply(HttpRequestMock, :request, [env]) end)
  end

  setup_all do: clear_config([:rich_media, :enabled], true)

  test "returns error when no metadata present" do
    assert {:error, _} = Parser.parse("https://example.com/empty")
  end

  test "doesn't just add a title" do
    assert {:error, :invalid_metadata} = Parser.parse("https://example.com/non-ogp")
  end

  test "parses ogp" do
    assert Parser.parse("https://example.com/ogp") ==
             {:ok,
              %{
                "image" => "http://ia.media-imdb.com/images/rock.jpg",
                "title" => "The Rock",
                "description" =>
                  "Directed by Michael Bay. With Sean Connery, Nicolas Cage, Ed Harris, John Spencer.",
                "type" => "video.movie",
                "url" => "https://example.com/ogp"
              }}
  end

  test "falls back to <title> when ogp:title is missing" do
    assert Parser.parse("https://example.com/ogp-missing-title") ==
             {:ok,
              %{
                "image" => "http://ia.media-imdb.com/images/rock.jpg",
                "title" => "The Rock (1996)",
                "description" =>
                  "Directed by Michael Bay. With Sean Connery, Nicolas Cage, Ed Harris, John Spencer.",
                "type" => "video.movie",
                "url" => "https://example.com/ogp-missing-title"
              }}
  end

  test "parses twitter card" do
    assert Parser.parse("https://example.com/twitter-card") ==
             {:ok,
              %{
                "card" => "summary",
                "site" => "@flickr",
                "image" => "https://farm6.staticflickr.com/5510/14338202952_93595258ff_z.jpg",
                "title" => "Small Island Developing States Photo Submission",
                "description" => "View the album on Flickr.",
                "url" => "https://example.com/twitter-card"
              }}
  end

  test "parses OEmbed and filters HTML tags" do
    assert Parser.parse("https://example.com/oembed") ==
             {:ok,
              %{
                "author_name" => "\u202E\u202D\u202Cbees\u202C",
                "author_url" => "https://www.flickr.com/photos/bees/",
                "cache_age" => 3600,
                "flickr_type" => "photo",
                "height" => "768",
                "html" =>
                  "<a href=\"https://www.flickr.com/photos/bees/2362225867/\" title=\"Bacon Lollys by \u202E\u202D\u202Cbees\u202C, on Flickr\"><img src=\"https://farm4.staticflickr.com/3040/2362225867_4a87ab8baf_b.jpg\" width=\"1024\" height=\"768\" alt=\"Bacon Lollys\"/></a>",
                "license" => "All Rights Reserved",
                "license_id" => 0,
                "provider_name" => "Flickr",
                "provider_url" => "https://www.flickr.com/",
                "thumbnail_height" => 150,
                "thumbnail_url" =>
                  "https://farm4.staticflickr.com/3040/2362225867_4a87ab8baf_q.jpg",
                "thumbnail_width" => 150,
                "title" => "Bacon Lollys",
                "type" => "photo",
                "url" => "https://example.com/oembed",
                "version" => "1.0",
                "web_page" => "https://www.flickr.com/photos/bees/2362225867/",
                "web_page_short_url" => "https://flic.kr/p/4AK2sc",
                "width" => "1024"
              }}
  end

  test "rejects invalid OGP data" do
    assert {:error, _} = Parser.parse("https://example.com/malformed")
  end

  test "returns error if getting page was not successful" do
    assert {:error, :get} = Parser.parse("https://example.com/error")
  end

  test "does a HEAD request to check if the body is too large" do
    assert {:error, :body_too_large} = Parser.parse("https://example.com/huge-page")
  end

  test "does a HEAD request to check if the body is html" do
    assert {:error, :content_type} = Parser.parse("https://example.com/pdf-file")
  end

  test "refuses to crawl incomplete URLs" do
    url = "example.com/ogp"
    assert {:error, :validate} == Parser.parse(url)
  end

  test "refuses to crawl malformed URLs" do
    url = "example.com[]/ogp"
    assert {:error, :validate} == Parser.parse(url)
  end

  test "refuses to crawl URLs of private network from posts" do
    [
      "http://127.0.0.1:4000/notice/9kCP7VNyPJXFOXDrgO",
      "https://10.111.10.1/notice/9kCP7V",
      "https://172.16.32.40/notice/9kCP7V",
      "https://192.168.10.40/notice/9kCP7V",
      "https://pleroma.local/notice/9kCP7V"
    ]
    |> Enum.each(fn url ->
      assert {:error, :validate} == Parser.parse(url)
    end)
  end

  test "returns error when disabled" do
    clear_config([:rich_media, :enabled], false)

    assert match?({:error, :rich_media_disabled}, Parser.parse("https://example.com/ogp"))
  end
end
