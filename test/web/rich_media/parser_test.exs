defmodule Pleroma.Web.RichMedia.ParserTest do
  use ExUnit.Case, async: true

  setup do
    Tesla.Mock.mock(fn
      %{
        method: :get,
        url: "http://example.com/ogp"
      } ->
        %Tesla.Env{status: 200, body: File.read!("test/fixtures/rich_media/ogp.html")}
    end)

    :ok
  end

  test "parses ogp" do
    assert Pleroma.Web.RichMedia.Parser.parse("http://example.com/ogp") ==
             %Pleroma.Web.RichMedia.Data{
               description: nil,
               image: "http://ia.media-imdb.com/images/rock.jpg",
               title: "The Rock",
               type: "video.movie",
               url: "http://www.imdb.com/title/tt0117500/"
             }
  end
end
