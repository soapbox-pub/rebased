# Pleroma: A lightweight social networking server
# Copyright © 2017-2022 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Upload.Filter.AnalyzeMetadataTest do
  use Pleroma.DataCase, async: true
  alias Pleroma.Upload.Filter.AnalyzeMetadata

  test "adds the dimensions and blurhash for images" do
    upload = %Pleroma.Upload{
      name: "an… image.jpg",
      content_type: "image/jpeg",
      path: Path.absname("test/fixtures/image.jpg"),
      tempfile: Path.absname("test/fixtures/image.jpg")
    }

    {:ok, :filtered, meta} = AnalyzeMetadata.filter(upload)

    assert %{width: 1024, height: 768} = meta
    assert meta.blurhash
  end

  test "adds the dimensions for videos" do
    upload = %Pleroma.Upload{
      name: "coolvideo.mp4",
      content_type: "video/mp4",
      path: Path.absname("test/fixtures/video.mp4"),
      tempfile: Path.absname("test/fixtures/video.mp4")
    }

    assert {:ok, :filtered, %{width: 480, height: 480}} = AnalyzeMetadata.filter(upload)
  end
end
