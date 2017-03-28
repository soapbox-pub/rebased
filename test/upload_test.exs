defmodule Pleroma.UploadTest do
  alias Pleroma.Upload
  use Pleroma.DataCase

  describe "Storing a file" do
    test "copies the file to the configured folder" do
      file = %Plug.Upload{content_type: "image/jpg", path: Path.absname("test/fixtures/image.jpg"), filename: "an_image.jpg"}
      data = Upload.store(file)
      assert data["name"] == "an_image.jpg"
    end
  end
end
