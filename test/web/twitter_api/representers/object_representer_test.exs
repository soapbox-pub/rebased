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
        ]
      }
    }

    expected_object = %{
      id: 5,
      url: "someurl",
      mimetype: "sometype",
      oembed: false
    }

    assert expected_object == ObjectRepresenter.to_map(object)
  end
end
