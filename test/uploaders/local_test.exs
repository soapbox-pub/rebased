# Pleroma: A lightweight social networking server
# Copyright © 2017-2019 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Uploaders.LocalTest do
  use Pleroma.DataCase
  alias Pleroma.Uploaders.Local

  describe "get_file/1" do
    test "it returns path to local folder for files" do
      assert Local.get_file("") == {:ok, {:static_dir, "test/uploads"}}
    end
  end

  describe "put_file/1" do
    test "put file to local folder" do
      file_path = "local_upload/files/image.jpg"

      file = %Pleroma.Upload{
        name: "image.jpg",
        content_type: "image/jpg",
        path: file_path,
        tempfile: Path.absname("test/fixtures/image_tmp.jpg")
      }

      assert Local.put_file(file) == :ok

      assert Path.join([Local.upload_path(), file_path])
             |> File.exists?()
    end
  end
end
