# Pleroma: A lightweight social networking server
# Copyright © 2017-2021 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Upload.Filter.AnalyzeMetadataTest do
  use Pleroma.DataCase, async: true
  alias Pleroma.Upload.Filter.AnalyzeMetadata

  test "adds the image dimensions" do
    upload = %Pleroma.Upload{
      name: "an… image.jpg",
      content_type: "image/jpeg",
      path: Path.absname("test/fixtures/image.jpg"),
      tempfile: Path.absname("test/fixtures/image.jpg")
    }

    assert {:ok, :filtered, %{width: 1024, height: 768}} = AnalyzeMetadata.filter(upload)
  end
end
