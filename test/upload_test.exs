defmodule Pleroma.UploadTest do
  alias Pleroma.Upload
  use Pleroma.DataCase

  describe "Storing a file with the Local uploader" do
    setup do
      uploader = Pleroma.Config.get([Pleroma.Upload, :uploader])

      unless uploader == Pleroma.Uploaders.Local do
        on_exit(fn ->
          Pleroma.Config.put([Pleroma.Upload, :uploader], uploader)
        end)
      end

      :ok
    end

    test "returns a media url" do
      File.cp!("test/fixtures/image.jpg", "test/fixtures/image_tmp.jpg")

      file = %Plug.Upload{
        content_type: "image/jpg",
        path: Path.absname("test/fixtures/image_tmp.jpg"),
        filename: "image.jpg"
      }

      {:ok, data} = Upload.store(file)

      assert %{"url" => [%{"href" => url}]} = data

      assert String.starts_with?(url, Pleroma.Web.base_url() <> "/media/")
    end

    test "copies the file to the configured folder with deduping" do
      File.cp!("test/fixtures/image.jpg", "test/fixtures/image_tmp.jpg")

      file = %Plug.Upload{
        content_type: "image/jpg",
        path: Path.absname("test/fixtures/image_tmp.jpg"),
        filename: "an [image.jpg"
      }

      {:ok, data} = Upload.store(file, dedupe: true)

      assert data["name"] ==
               "e7a6d0cf595bff76f14c9a98b6c199539559e8b844e02e51e5efcfd1f614a2df.jpeg"
    end

    test "copies the file to the configured folder without deduping" do
      File.cp!("test/fixtures/image.jpg", "test/fixtures/image_tmp.jpg")

      file = %Plug.Upload{
        content_type: "image/jpg",
        path: Path.absname("test/fixtures/image_tmp.jpg"),
        filename: "an [image.jpg"
      }

      {:ok, data} = Upload.store(file, dedupe: false)
      assert data["name"] == "an [image.jpg"
    end

    test "fixes incorrect content type" do
      File.cp!("test/fixtures/image.jpg", "test/fixtures/image_tmp.jpg")

      file = %Plug.Upload{
        content_type: "application/octet-stream",
        path: Path.absname("test/fixtures/image_tmp.jpg"),
        filename: "an [image.jpg"
      }

      {:ok, data} = Upload.store(file, dedupe: true)
      assert hd(data["url"])["mediaType"] == "image/jpeg"
    end

    test "adds missing extension" do
      File.cp!("test/fixtures/image.jpg", "test/fixtures/image_tmp.jpg")

      file = %Plug.Upload{
        content_type: "image/jpg",
        path: Path.absname("test/fixtures/image_tmp.jpg"),
        filename: "an [image"
      }

      {:ok, data} = Upload.store(file, dedupe: false)
      assert data["name"] == "an [image.jpg"
    end

    test "fixes incorrect file extension" do
      File.cp!("test/fixtures/image.jpg", "test/fixtures/image_tmp.jpg")

      file = %Plug.Upload{
        content_type: "image/jpg",
        path: Path.absname("test/fixtures/image_tmp.jpg"),
        filename: "an [image.blah"
      }

      {:ok, data} = Upload.store(file, dedupe: false)
      assert data["name"] == "an [image.jpg"
    end

    test "don't modify filename of an unknown type" do
      File.cp("test/fixtures/test.txt", "test/fixtures/test_tmp.txt")

      file = %Plug.Upload{
        content_type: "text/plain",
        path: Path.absname("test/fixtures/test_tmp.txt"),
        filename: "test.txt"
      }

      {:ok, data} = Upload.store(file, dedupe: false)
      assert data["name"] == "test.txt"
    end
  end
end
