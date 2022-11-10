# Pleroma: A lightweight social networking server
# Copyright © 2017-2021 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Upload.Filter.HeifToJpegTest do
  use Pleroma.DataCase, async: true
  alias Pleroma.Upload.Filter

  test "apply HeicToJpeg filter" do
    File.cp!(
      "test/fixtures/image.heic",
      "test/fixtures/heictmp"
    )

    upload = %Pleroma.Upload{
      name: "image.heic",
      content_type: "image/heic",
      path: Path.absname("test/fixtures/image.heic"),
      tempfile: Path.absname("test/fixtures/heictmp")
    }

    {:ok, :filtered, result} = Filter.HeifToJpeg.filter(upload)

    assert result.content_type == "image/jpeg"
    assert result.name == "image.jpg"
    assert String.ends_with?(result.path, "jpg")

    assert {:ok,
            %Majic.Result{
              content:
                "JPEG image data, JFIF standard 1.02, resolution (DPI), density 96x96, segment length 16, progressive, precision 8, 1024x768, components 3",
              encoding: "binary",
              mime_type: "image/jpeg"
            }} == Majic.perform(result.path, pool: Pleroma.MajicPool)

    on_exit(fn -> File.rm!("test/fixtures/heictmp") end)
  end
end
