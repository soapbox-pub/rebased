defmodule Pleroma.Web.TwitterAPI.Representers.ObjectReprenterTest do
  use Pleroma.DataCase

  alias Pleroma.Object
  alias Pleroma.Web.TwitterAPI.Representers.ObjectRepresenter

  test "represent an image attachment" do
    object = %Object{
      id: 5,
      data: %{
        "type" => "Image",
        "url" => [
          %{
            "mediaType" => "sometype",
            "href" => "someurl"
          }
        ],
        "uuid" => 6
      }
    }

    expected_object = %{
      id: 6,
      url: "someurl",
      mimetype: "sometype",
      oembed: false
    }

    assert expected_object == ObjectRepresenter.to_map(object)
  end

  test "represents mastodon-style attachments" do
    object = %Object{
      id: nil,
      data: %{
        "mediaType" => "image/png",
        "name" => "blabla", "type" => "Document",
        "url" => "http://mastodon.example.org/system/media_attachments/files/000/000/001/original/8619f31c6edec470.png"
      }
    }

    expected_object = %{
      url: "http://mastodon.example.org/system/media_attachments/files/000/000/001/original/8619f31c6edec470.png",
      mimetype: "image/png",
      oembed: false,
      id: nil
    }

    assert expected_object == ObjectRepresenter.to_map(object)
  end
end
