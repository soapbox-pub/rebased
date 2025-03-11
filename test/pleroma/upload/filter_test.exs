# Pleroma: A lightweight social networking server
# Copyright © 2017-2022 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Upload.FilterTest do
  use Pleroma.DataCase

  import Mox
  alias Pleroma.StaticStubbedConfigMock, as: ConfigMock
  alias Pleroma.Upload.Filter

  test "applies filters" do
    ConfigMock
    |> stub(:get, fn [Pleroma.Upload.Filter.AnonymizeFilename, :text] -> "custom-file.png" end)

    File.cp!(
      "test/fixtures/image.jpg",
      "test/fixtures/image_tmp.jpg"
    )

    upload = %Pleroma.Upload{
      name: "an… image.jpg",
      content_type: "image/jpeg",
      path: Path.absname("test/fixtures/image_tmp.jpg"),
      tempfile: Path.absname("test/fixtures/image_tmp.jpg")
    }

    assert Filter.filter([], upload) == {:ok, upload}

    assert {:ok, upload} = Filter.filter([Pleroma.Upload.Filter.AnonymizeFilename], upload)
    assert upload.name == "custom-file.png"
  end
end
