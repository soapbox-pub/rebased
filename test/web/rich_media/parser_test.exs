defmodule Pleroma.Web.RichMedia.ParserTest do
  use ExUnit.Case, async: true

  setup do
    Tesla.Mock.mock(fn
      %{
        method: :get,
        url: "http://example.com/ogp"
      } ->
        %Tesla.Env{status: 200, body: File.read!("test/fixtures/rich_media/ogp.html")}

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
end
