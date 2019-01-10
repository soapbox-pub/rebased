defmodule Pleroma.Web.RichMedia.ParserTest do
  use ExUnit.Case, async: true

  setup do
    Tesla.Mock.mock(fn
      %{
        method: :get,
        url: "http://example.com/ogp"
      } ->
        %Tesla.Env{status: 200, body: File.read!("test/fixtures/rich_media/ogp.html")}

      %{
        method: :get,
        url: "http://example.com/twitter-card"
      } ->
        %Tesla.Env{status: 200, body: File.read!("test/fixtures/rich_media/twitter_card.html")}

      %{method: :get, url: "http://example.com/empty"} ->
        %Tesla.Env{status: 200, body: "hello"}
    end)

    :ok
  end

  test "returns error when no metadata present" do
    assert {:error, _} = Pleroma.Web.RichMedia.Parser.parse("http://example.com/empty")
  end

  test "parses ogp" do
    assert Pleroma.Web.RichMedia.Parser.parse("http://example.com/ogp") ==
             {:ok,
              %{
                image: "http://ia.media-imdb.com/images/rock.jpg",
                title: "The Rock",
                type: "video.movie",
                url: "http://www.imdb.com/title/tt0117500/"
              }}
  end

  test "parses twitter card" do
    assert Pleroma.Web.RichMedia.Parser.parse("http://example.com/twitter-card") ==
             {:ok,
              %{
                card: "summary",
                site: "@flickr",
                image: "https://farm6.staticflickr.com/5510/14338202952_93595258ff_z.jpg",
                title: "Small Island Developing States Photo Submission",
                description: "View the album on Flickr."
              }}
  end
end
