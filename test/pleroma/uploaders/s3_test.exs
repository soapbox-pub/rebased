# Pleroma: A lightweight social networking server
# Copyright © 2017-2022 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Uploaders.S3Test do
  use Pleroma.DataCase

  alias Pleroma.Uploaders.S3

  import Mock
  import ExUnit.CaptureLog

  setup do
    clear_config([Pleroma.Upload, :uploader], Pleroma.Uploaders.S3)
    clear_config([Pleroma.Upload, :base_url], "https://s3.amazonaws.com")
    clear_config([Pleroma.Uploaders.S3])
    clear_config([Pleroma.Uploaders.S3, :bucket], "test_bucket")
  end

  describe "get_file/1" do
    test "it returns path to local folder for files" do
      assert S3.get_file("test_image.jpg") == {
               :ok,
               {:url, "https://s3.amazonaws.com/test_bucket/test_image.jpg"}
             }
    end

    test "it returns path without bucket when truncated_namespace set to ''" do
      clear_config([Pleroma.Uploaders.S3],
        bucket: "test_bucket",
        bucket_namespace: "myaccount",
        truncated_namespace: ""
      )

      clear_config([Pleroma.Upload, :base_url], "https://s3.amazonaws.com")

      assert S3.get_file("test_image.jpg") == {
               :ok,
               {:url, "https://s3.amazonaws.com/test_image.jpg"}
             }
    end

    test "it returns path with bucket namespace when namespace is set" do
      clear_config([Pleroma.Uploaders.S3],
        bucket: "test_bucket",
        bucket_namespace: "family"
      )

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

      [file_upload: file_upload]
    end

    test "save file", %{file_upload: file_upload} do
      with_mock ExAws, request: fn _ -> {:ok, :ok} end do
        assert S3.put_file(file_upload) == {:ok, {:file, "test_folder/image-tet.jpg"}}
      end
    end

    test "returns error", %{file_upload: file_upload} do
      with_mock ExAws, request: fn _ -> {:error, "S3 Upload failed"} end do
        assert capture_log(fn ->
                 assert S3.put_file(file_upload) == {:error, "S3 Upload failed"}
               end) =~ "Elixir.Pleroma.Uploaders.S3: {:error, \"S3 Upload failed\"}"
      end
    end
  end

  describe "delete_file/1" do
    test_with_mock "deletes file", ExAws, request: fn _req -> {:ok, %{status_code: 204}} end do
      assert :ok = S3.delete_file("image.jpg")
      assert_called(ExAws.request(:_))
    end
  end
end
