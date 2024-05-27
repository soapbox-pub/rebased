# Pleroma: A lightweight social networking server
# Copyright © 2017-2022 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Uploaders.S3Test do
  use Pleroma.DataCase, async: true

  alias Pleroma.UnstubbedConfigMock, as: ConfigMock
  alias Pleroma.Uploaders.S3
  alias Pleroma.Uploaders.S3.ExAwsMock

  import Mox
  import ExUnit.CaptureLog

  describe "get_file/1" do
    test "it returns url for files" do
      ConfigMock
      |> expect(:get, 6, fn key ->
        [
          {Pleroma.Upload,
           [uploader: Pleroma.Uploaders.S3, base_url: "https://s3.amazonaws.com"]},
          {Pleroma.Uploaders.S3, [bucket: "test_bucket"]}
        ]
        |> get_in(key)
      end)

      assert S3.get_file("test_image.jpg") == {
               :ok,
               {:url, "https://s3.amazonaws.com/test_bucket/test_image.jpg"}
             }
    end

    test "it returns path without bucket when truncated_namespace set to ''" do
      ConfigMock
      |> expect(:get, 6, fn key ->
        [
          {Pleroma.Upload,
           [uploader: Pleroma.Uploaders.S3, base_url: "https://s3.amazonaws.com"]},
          {Pleroma.Uploaders.S3,
           [bucket: "test_bucket", truncated_namespace: "", bucket_namespace: "myaccount"]}
        ]
        |> get_in(key)
      end)

      assert S3.get_file("test_image.jpg") == {
               :ok,
               {:url, "https://s3.amazonaws.com/test_image.jpg"}
             }
    end

    test "it returns path with bucket namespace when namespace is set" do
      ConfigMock
      |> expect(:get, 6, fn key ->
        [
          {Pleroma.Upload,
           [uploader: Pleroma.Uploaders.S3, base_url: "https://s3.amazonaws.com"]},
          {Pleroma.Uploaders.S3, [bucket: "test_bucket", bucket_namespace: "family"]}
        ]
        |> get_in(key)
      end)

      assert S3.get_file("test_image.jpg") == {
               :ok,
               {:url, "https://s3.amazonaws.com/family:test_bucket/test_image.jpg"}
             }
    end
  end

  describe "put_file/1" do
    setup do
      file_upload = %Pleroma.Upload{
        name: "image-tet.jpg",
        content_type: "image/jpeg",
        path: "test_folder/image-tet.jpg",
        tempfile: Path.absname("test/instance_static/add/shortcode.png")
      }

      ConfigMock
      |> expect(:get, fn [Pleroma.Uploaders.S3] ->
        [
          bucket: "test_bucket"
        ]
      end)

      [file_upload: file_upload]
    end

    test "save file", %{file_upload: file_upload} do
      ExAwsMock
      |> expect(:request, fn _req -> {:ok, %{status_code: 200}} end)

      assert S3.put_file(file_upload) == {:ok, {:file, "test_folder/image-tet.jpg"}}
    end

    test "returns error", %{file_upload: file_upload} do
      ExAwsMock
      |> expect(:request, fn _req -> {:error, "S3 Upload failed"} end)

      assert capture_log(fn ->
               assert S3.put_file(file_upload) == {:error, "S3 Upload failed"}
             end) =~ "Elixir.Pleroma.Uploaders.S3: {:error, \"S3 Upload failed\"}"
    end
  end

  describe "delete_file/1" do
    test "deletes file" do
      ExAwsMock
      |> expect(:request, fn _req -> {:ok, %{status_code: 204}} end)

      ConfigMock
      |> expect(:get, fn [Pleroma.Uploaders.S3, :bucket] -> "test_bucket" end)

      assert :ok = S3.delete_file("image.jpg")
    end
  end
end
