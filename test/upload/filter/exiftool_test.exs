# Pleroma: A lightweight social networking server
# Copyright © 2017-2020 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Upload.Filter.ExiftoolTest do
  use Pleroma.DataCase
  alias Pleroma.Upload.Filter

  test "apply exiftool filter" do
    File.cp!(
      "test/fixtures/DSCN0010.jpg",
      "test/fixtures/DSCN0010_tmp.jpg"
    )

    upload = %Pleroma.Upload{
      name: "image_with_GPS_data.jpg",
      content_type: "image/jpg",
      path: Path.absname("test/fixtures/DSCN0010.jpg"),
      tempfile: Path.absname("test/fixtures/DSCN0010_tmp.jpg")
    }

    assert Filter.Exiftool.filter(upload) == :ok

    {exif_original, 0} = System.cmd("exiftool", ["test/fixtures/DSCN0010.jpg"])
    {exif_filtered, 0} = System.cmd("exiftool", ["test/fixtures/DSCN0010_tmp.jpg"])

    refute exif_original == exif_filtered
    assert String.match?(exif_original, ~r/GPS/)
    refute String.match?(exif_filtered, ~r/GPS/)
  end
end
