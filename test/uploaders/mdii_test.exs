# Pleroma: A lightweight social networking server
# Copyright © 2017-2019 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Uploaders.MDIITest do
  use Pleroma.DataCase
  alias Pleroma.Uploaders.MDII
  import Tesla.Mock

  describe "get_file/1" do
    test "it returns path to local folder for files" do
      assert MDII.get_file("") == {:ok, {:static_dir, "test/uploads"}}
    end
  end

  describe "put_file/1" do
    setup do
      file_upload = %Pleroma.Upload{
        name: "mdii-image.jpg",
        content_type: "image/jpg",
        path: "test_folder/mdii-image.jpg",
        tempfile: Path.absname("test/fixtures/image_tmp.jpg")
      }

      [file_upload: file_upload]
    end

    test "save file", %{file_upload: file_upload} do
      mock(fn
        %{method: :post, url: "https://mdii.sakura.ne.jp/mdii-post.cgi?jpg"} ->
          %Tesla.Env{status: 200, body: "mdii-image"}
      end)

      assert MDII.put_file(file_upload) ==
               {:ok, {:url, "https://mdii.sakura.ne.jp/mdii-image.jpg"}}
    end

    test "save file to local if MDII  isn`t available", %{file_upload: file_upload} do
      mock(fn
        %{method: :post, url: "https://mdii.sakura.ne.jp/mdii-post.cgi?jpg"} ->
          %Tesla.Env{status: 500}
      end)

      assert MDII.put_file(file_upload) == :ok

      assert Path.join([Pleroma.Uploaders.Local.upload_path(), file_upload.path])
             |> File.exists?()
    end
  end
end
