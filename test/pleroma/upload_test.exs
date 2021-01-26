# Pleroma: A lightweight social networking server
# Copyright © 2017-2021 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.UploadTest do
  use Pleroma.DataCase

  import ExUnit.CaptureLog

  alias Pleroma.Upload
  alias Pleroma.Uploaders.Uploader

  @upload_file %Plug.Upload{
    content_type: "image/jpeg",
    path: Path.absname("test/fixtures/image_tmp.jpg"),
    filename: "image.jpg"
  }

  defmodule TestUploaderBase do
    def put_file(%{path: path} = _upload, module_name) do
      task_pid =
        Task.async(fn ->
          :timer.sleep(10)

          {Uploader, path}
          |> :global.whereis_name()
          |> send({Uploader, self(), {:test}, %{}})

          assert_receive {Uploader, {:test}}, 4_000
        end)

      Agent.start(fn -> task_pid end, name: module_name)

      :wait_callback
    end
  end

  describe "Tried storing a file when http callback response success result" do
    defmodule TestUploaderSuccess do
      def http_callback(conn, _params),
        do: {:ok, conn, {:file, "post-process-file.jpg"}}

      def put_file(upload), do: TestUploaderBase.put_file(upload, __MODULE__)
    end

    setup do: [uploader: TestUploaderSuccess]
    setup [:ensure_local_uploader]

    test "it returns file" do
      File.cp!("test/fixtures/image.jpg", "test/fixtures/image_tmp.jpg")

      assert Upload.store(@upload_file) ==
               {:ok,
                %{
                  "name" => "image.jpg",
                  "type" => "Document",
                  "mediaType" => "image/jpeg",
                  "url" => [
                    %{
                      "href" => "http://localhost:4001/media/post-process-file.jpg",
                      "mediaType" => "image/jpeg",
                      "type" => "Link"
                    }
                  ]
                }}

      Task.await(Agent.get(TestUploaderSuccess, fn task_pid -> task_pid end))
    end
  end

  describe "Tried storing a file when http callback response error" do
    defmodule TestUploaderError do
      def http_callback(conn, _params), do: {:error, conn, "Errors"}

      def put_file(upload), do: TestUploaderBase.put_file(upload, __MODULE__)
    end

    setup do: [uploader: TestUploaderError]
    setup [:ensure_local_uploader]

    test "it returns error" do
      File.cp!("test/fixtures/image.jpg", "test/fixtures/image_tmp.jpg")

      assert capture_log(fn ->
               assert Upload.store(@upload_file) == {:error, "Errors"}
               Task.await(Agent.get(TestUploaderError, fn task_pid -> task_pid end))
             end) =~
               "[error] Elixir.Pleroma.Upload store (using Pleroma.UploadTest.TestUploaderError) failed: \"Errors\""
    end
  end

  describe "Tried storing a file when http callback doesn't response by timeout" do
    defmodule(TestUploader, do: def(put_file(_upload), do: :wait_callback))
    setup do: [uploader: TestUploader]
    setup [:ensure_local_uploader]

    test "it returns error" do
      File.cp!("test/fixtures/image.jpg", "test/fixtures/image_tmp.jpg")

      assert capture_log(fn ->
               assert Upload.store(@upload_file) == {:error, "Uploader callback timeout"}
             end) =~
               "[error] Elixir.Pleroma.Upload store (using Pleroma.UploadTest.TestUploader) failed: \"Uploader callback timeout\""
    end
  end

  describe "Storing a file with the Local uploader" do
    setup [:ensure_local_uploader]

    test "does not allow descriptions longer than the post limit" do
      clear_config([:instance, :description_limit], 2)
      File.cp!("test/fixtures/image.jpg", "test/fixtures/image_tmp.jpg")

      file = %Plug.Upload{
        content_type: "image/jpeg",
        path: Path.absname("test/fixtures/image_tmp.jpg"),
        filename: "image.jpg"
      }

      {:error, :description_too_long} = Upload.store(file, description: "123")
    end

    test "returns a media url" do
      File.cp!("test/fixtures/image.jpg", "test/fixtures/image_tmp.jpg")

      file = %Plug.Upload{
        content_type: "image/jpeg",
        path: Path.absname("test/fixtures/image_tmp.jpg"),
        filename: "image.jpg"
      }

      {:ok, data} = Upload.store(file)

      assert %{"url" => [%{"href" => url}]} = data

      assert String.starts_with?(url, Pleroma.Upload.base_url())
    end

    test "copies the file to the configured folder with deduping" do
      File.cp!("test/fixtures/image.jpg", "test/fixtures/image_tmp.jpg")

      file = %Plug.Upload{
        content_type: "image/jpeg",
        path: Path.absname("test/fixtures/image_tmp.jpg"),
        filename: "an [image.jpg"
      }

      {:ok, data} = Upload.store(file, filters: [Pleroma.Upload.Filter.Dedupe])

      assert List.first(data["url"])["href"] ==
               Pleroma.Upload.base_url() <>
                 "e30397b58d226d6583ab5b8b3c5defb0c682bda5c31ef07a9f57c1c4986e3781.jpg"
    end

    test "copies the file to the configured folder without deduping" do
      File.cp!("test/fixtures/image.jpg", "test/fixtures/image_tmp.jpg")

      file = %Plug.Upload{
        content_type: "image/jpeg",
        path: Path.absname("test/fixtures/image_tmp.jpg"),
        filename: "an [image.jpg"
      }

      {:ok, data} = Upload.store(file)
      assert data["name"] == "an [image.jpg"
    end

    test "fixes incorrect content type when base64 is given" do
      params = %{
        img: "data:image/png;base64,#{Base.encode64(File.read!("test/fixtures/image.jpg"))}"
      }

      {:ok, data} = Upload.store(params)
      assert hd(data["url"])["mediaType"] == "image/jpeg"
    end

    test "adds extension when base64 is given" do
      File.cp!("test/fixtures/image.jpg", "test/fixtures/image_tmp.jpg")

      params = %{
        img: "data:image/png;base64,#{Base.encode64(File.read!("test/fixtures/image.jpg"))}"
      }

      {:ok, data} = Upload.store(params)
      assert String.ends_with?(data["name"], ".jpg")
    end

    test "copies the file to the configured folder with anonymizing filename" do
      File.cp!("test/fixtures/image.jpg", "test/fixtures/image_tmp.jpg")

      file = %Plug.Upload{
        content_type: "image/jpeg",
        path: Path.absname("test/fixtures/image_tmp.jpg"),
        filename: "an [image.jpg"
      }

      {:ok, data} = Upload.store(file, filters: [Pleroma.Upload.Filter.AnonymizeFilename])

      refute data["name"] == "an [image.jpg"
    end

    test "escapes invalid characters in url" do
      File.cp!("test/fixtures/image.jpg", "test/fixtures/image_tmp.jpg")

      file = %Plug.Upload{
        content_type: "image/jpeg",
        path: Path.absname("test/fixtures/image_tmp.jpg"),
        filename: "an… image.jpg"
      }

      {:ok, data} = Upload.store(file)
      [attachment_url | _] = data["url"]

      assert Path.basename(attachment_url["href"]) == "an%E2%80%A6%20image.jpg"
    end

    test "escapes reserved uri characters" do
      File.cp!("test/fixtures/image.jpg", "test/fixtures/image_tmp.jpg")

      file = %Plug.Upload{
        content_type: "image/jpeg",
        path: Path.absname("test/fixtures/image_tmp.jpg"),
        filename: ":?#[]@!$&\\'()*+,;=.jpg"
      }

      {:ok, data} = Upload.store(file)
      [attachment_url | _] = data["url"]

      assert Path.basename(attachment_url["href"]) ==
               "%3A%3F%23%5B%5D%40%21%24%26%5C%27%28%29%2A%2B%2C%3B%3D.jpg"
    end
  end

  describe "Setting a custom base_url for uploaded media" do
    setup do: clear_config([Pleroma.Upload, :base_url], "https://cache.pleroma.social")

    test "returns a media url with configured base_url" do
      base_url = Pleroma.Config.get([Pleroma.Upload, :base_url])

      File.cp!("test/fixtures/image.jpg", "test/fixtures/image_tmp.jpg")

      file = %Plug.Upload{
        content_type: "image/jpeg",
        path: Path.absname("test/fixtures/image_tmp.jpg"),
        filename: "image.jpg"
      }

      {:ok, data} = Upload.store(file, base_url: base_url)

      assert %{"url" => [%{"href" => url}]} = data

      refute String.starts_with?(url, base_url <> "/media/")
    end
  end
end
