# Pleroma: A lightweight social networking server
# Copyright © 2017-2022 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Upload.Filter.Exiftool.StripLocationTest do
  use Pleroma.DataCase, async: true
  alias Pleroma.Upload.Filter

  test "apply exiftool filter" do
    assert Pleroma.Utils.command_available?("exiftool")

    ~w{jpg png}
    |> Enum.map(fn type ->
      File.cp!(
        "test/fixtures/DSCN0010.#{type}",
        "test/fixtures/DSCN0010_tmp.#{type}"
      )

      upload = %Pleroma.Upload{
        name: "image_with_GPS_data.#{type}",
        content_type: "image/jpeg",
        path: Path.absname("test/fixtures/DSCN0010.#{type}"),
        tempfile: Path.absname("test/fixtures/DSCN0010_tmp.#{type}")
      }

      assert Filter.Exiftool.StripLocation.filter(upload) == {:ok, :filtered}

      {exif_original, 0} = System.cmd("exiftool", ["test/fixtures/DSCN0010.#{type}"])
      {exif_filtered, 0} = System.cmd("exiftool", ["test/fixtures/DSCN0010_tmp.#{type}"])

      assert String.match?(exif_original, ~r/GPS/)
      refute String.match?(exif_filtered, ~r/GPS/)
    end)
  end

  test "verify webp, heic, svg files are skipped" do
    uploads =
      ~w{webp heic svg svg+xml}
      |> Enum.map(fn type ->
        %Pleroma.Upload{
          name: "sample.#{type}",
          content_type: "image/#{type}"
        }
      end)

    uploads
    |> Enum.each(fn upload ->
      assert Filter.Exiftool.StripLocation.filter(upload) == {:ok, :noop}
    end)
  end
end
