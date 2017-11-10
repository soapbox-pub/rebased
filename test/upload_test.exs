defmodule Pleroma.UploadTest do
  alias Pleroma.Upload
  use Pleroma.DataCase

  describe "Storing a file" do
    test "copies the file to the configured folder" do
      file = %Plug.Upload{content_type: "image/jpg", path: Path.absname("test/fixtures/image.jpg"), filename: "an [image.jpg"}
      data = Upload.store(file)
      assert data["name"] == "an [image.jpg"
      assert List.first(data["url"])["href"] == "http://localhost:4001/media/#{data["uuid"]}/an%20%5Bimage.jpg"
    end

    test "fixes an incorrect content type" do
      file = %Plug.Upload{content_type: "application/octet-stream", path: Path.absname("test/fixtures/image.jpg"), filename: "an [image.jpg"}
      data = Upload.store(file)
      assert hd(data["url"])["mediaType"] == "image/jpeg"
    end

    test "does not modify a valid content type" do
      file = %Plug.Upload{content_type: "image/png", path: Path.absname("test/fixtures/image.jpg"), filename: "an [image.jpg"}
      data = Upload.store(file)
      assert hd(data["url"])["mediaType"] == "image/png"
    end
  end
end
