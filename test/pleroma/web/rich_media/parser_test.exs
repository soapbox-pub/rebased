# Pleroma: A lightweight social networking server
# Copyright © 2017-2021 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.RichMedia.ParserTest do
  use ExUnit.Case, async: true

  alias Pleroma.Web.RichMedia.Parser

  setup do
    Tesla.Mock.mock(fn
      %{
        method: :get,
        url: "http://example.com/ogp"
      } ->
        %Tesla.Env{status: 200, body: File.read!("test/fixtures/rich_media/ogp.html")}

      %{
        method: :get,
        url: "http://example.com/non-ogp"
      } ->
        %Tesla.Env{status: 200, body: File.read!("test/fixtures/rich_media/non_ogp_embed.html")}

      %{
        method: :get,
        url: "http://example.com/ogp-missing-title"
      } ->
        %Tesla.Env{
          status: 200,
          body: File.read!("test/fixtures/rich_media/ogp-missing-title.html")
        }

      %{
        method: :get,
        url: "http://example.com/twitter-card"
      } ->
        %Tesla.Env{status: 200, body: File.read!("test/fixtures/rich_media/twitter_card.html")}

      %{
        method: :get,
        url: "http://example.com/oembed"
      } ->
        %Tesla.Env{status: 200, body: File.read!("test/fixtures/rich_media/oembed.html")}

      %{
        method: :get,
        url: "http://example.com/oembed.json"
      } ->
        %Tesla.Env{status: 200, body: File.read!("test/fixtures/rich_media/oembed.json")}

      %{method: :get, url: "http://example.com/empty"} ->
        %Tesla.Env{status: 200, body: "hello"}

      %{method: :get, url: "http://example.com/malformed"} ->
        %Tesla.Env{status: 200, body: File.read!("test/fixtures/rich_media/malformed-data.html")}

      %{method: :get, url: "http://example.com/error"} ->
        {:error, :overload}

      %{
        method: :head,
        url: "http://example.com/huge-page"
      } ->
        %Tesla.Env{
          status: 200,
          headers: [{"content-length", "2000001"}, {"content-type", "text/html"}]
        }

      %{
        method: :head,
        url: "http://example.com/pdf-file"
      } ->
        %Tesla.Env{
          status: 200,
          headers: [{"content-length", "1000000"}, {"content-type", "application/pdf"}]
        }

      %{method: :head} ->
        %Tesla.Env{status: 404, body: "", headers: []}
    end)

    :ok
  end

  test "returns error when no metadata present" do
    assert {:error, _} = Parser.parse("http://example.com/empty")
  end

  test "doesn't just add a title" do
    assert {:error, {:invalid_metadata, _}} = Parser.parse("http://example.com/non-ogp")
  end

  test "parses ogp" do
    assert Parser.parse("http://example.com/ogp") ==
             {:ok,
              %{
                "image" => "http://ia.media-imdb.com/images/rock.jpg",
                "title" => "The Rock",
                "description" =>
                  "Directed by Michael Bay. With Sean Connery, Nicolas Cage, Ed Harris, John Spencer.",
                "type" => "video.movie",
                "url" => "http://example.com/ogp"
              }}
  end

  test "falls back to <title> when ogp:title is missing" do
    assert Parser.parse("http://example.com/ogp-missing-title") ==
             {:ok,
              %{
                "image" => "http://ia.media-imdb.com/images/rock.jpg",
                "title" => "The Rock (1996)",
                "description" =>
                  "Directed by Michael Bay. With Sean Connery, Nicolas Cage, Ed Harris, John Spencer.",
                "type" => "video.movie",
                "url" => "http://example.com/ogp-missing-title"
              }}
  end

  test "parses twitter card" do
    assert Parser.parse("http://example.com/twitter-card") ==
             {:ok,
              %{
                "card" => "summary",
                "site" => "@flickr",
                "image" => "https://farm6.staticflickr.com/5510/14338202952_93595258ff_z.jpg",
                "title" => "Small Island Developing States Photo Submission",
                "description" => "View the album on Flickr.",
                "url" => "http://example.com/twitter-card"
              }}
  end

  test "parses OEmbed" do
    assert Parser.parse("http://example.com/oembed") ==
             {:ok,
              %{
                "author_name" => "‮‭‬bees‬",
                "author_url" => "https://www.flickr.com/photos/bees/",
                "cache_age" => 3600,
                "flickr_type" => "photo",
                "height" => "768",
                "html" =>
                  "<a data-flickr-embed=\"true\" href=\"https://www.flickr.com/photos/bees/2362225867/\" title=\"Bacon Lollys by ‮‭‬bees‬, on Flickr\"><img src=\"https://farm4.staticflickr.com/3040/2362225867_4a87ab8baf_b.jpg\" width=\"1024\" height=\"768\" alt=\"Bacon Lollys\"></a><script async src=\"https://embedr.flickr.com/assets/client-code.js\" charset=\"utf-8\"></script>",
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
                "url" => "http://example.com/oembed",
                "version" => "1.0",
                "web_page" => "https://www.flickr.com/photos/bees/2362225867/",
                "web_page_short_url" => "https://flic.kr/p/4AK2sc",
                "width" => "1024"
              }}
  end

  test "rejects invalid OGP data" do
    assert {:error, _} = Parser.parse("http://example.com/malformed")
  end

  test "returns error if getting page was not successful" do
    assert {:error, :overload} = Parser.parse("http://example.com/error")
  end

  test "does a HEAD request to check if the body is too large" do
    assert {:error, :body_too_large} = Parser.parse("http://example.com/huge-page")
  end

  test "does a HEAD request to check if the body is html" do
    assert {:error, {:content_type, _}} = Parser.parse("http://example.com/pdf-file")
  end
end
