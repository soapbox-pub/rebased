# Pleroma: A lightweight social networking server
# Copyright © 2017-2021 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Upload.Filter.Exiftool.ReadDescriptionTest do
  use Pleroma.DataCase, async: true
  alias Pleroma.Upload.Filter

  @uploads %Pleroma.Upload{
    name: "portrait_of_owls_imagedescription_and_caption-abstract.jpg",
    content_type: "image/jpeg",
    path:
      Path.absname("test/fixtures/portrait_of_owls_imagedescription_and_caption-abstract.jpg"),
    tempfile:
      Path.absname("test/fixtures/portrait_of_owls_imagedescription_and_caption-abstract_tmp.jpg"),
    description: nil
  }

  test "keeps description when not empty" do
    uploads = %Pleroma.Upload{
      name: "portrait_of_owls_imagedescription_and_caption-abstract.jpg",
      content_type: "image/jpeg",
      path:
        Path.absname("test/fixtures/portrait_of_owls_imagedescription_and_caption-abstract.jpg"),
      tempfile:
        Path.absname(
          "test/fixtures/portrait_of_owls_imagedescription_and_caption-abstract_tmp.jpg"
        ),
      description: "Eight different owls"
    }

    assert Filter.Exiftool.ReadDescription.filter(uploads) ==
             {:ok, :noop}
  end

  test "otherwise returns ImageDescription when present" do
    uploads_after = %Pleroma.Upload{
      name: "portrait_of_owls_imagedescription_and_caption-abstract.jpg",
      content_type: "image/jpeg",
      path:
        Path.absname("test/fixtures/portrait_of_owls_imagedescription_and_caption-abstract.jpg"),
      tempfile:
        Path.absname(
          "test/fixtures/portrait_of_owls_imagedescription_and_caption-abstract_tmp.jpg"
        ),
      description: "Pictures of eight different owls"
    }

    assert Filter.Exiftool.ReadDescription.filter(@uploads) ==
             {:ok, :filtered, uploads_after}
  end

  test "otherwise returns iptc:Caption-Abstract when present" do
    upload = %Pleroma.Upload{
      name: "portrait_of_owls_caption-abstract.jpg",
      content_type: "image/jpeg",
      path: Path.absname("test/fixtures/portrait_of_owls_caption-abstract.jpg"),
      tempfile: Path.absname("test/fixtures/portrait_of_owls_caption-abstract_tmp.jpg"),
      description: nil
    }

    upload_after = %Pleroma.Upload{
      name: "portrait_of_owls_caption-abstract.jpg",
      content_type: "image/jpeg",
      path: Path.absname("test/fixtures/portrait_of_owls_caption-abstract.jpg"),
      tempfile: Path.absname("test/fixtures/portrait_of_owls_caption-abstract_tmp.jpg"),
      description: "Pictures of eight different owls - iptc"
    }

    assert Filter.Exiftool.ReadDescription.filter(upload) ==
             {:ok, :filtered, upload_after}
  end

  test "otherwise returns nil" do
    uploads = %Pleroma.Upload{
      name: "portrait_of_owls_no_description-abstract.jpg",
      content_type: "image/jpeg",
      path: Path.absname("test/fixtures/portrait_of_owls_no_description.jpg"),
      tempfile: Path.absname("test/fixtures/portrait_of_owls_no_description_tmp.jpg"),
      description: nil
    }

    assert Filter.Exiftool.ReadDescription.filter(uploads) ==
             {:ok, :filtered, uploads}
  end

  test "Return nil when image description from EXIF data exceeds the maximum length" do
    clear_config([:instance, :description_limit], 5)

    assert Filter.Exiftool.ReadDescription.filter(@uploads) ==
             {:ok, :filtered, @uploads}
  end

  test "Return nil when image description from EXIF data can't be read" do
    uploads = %Pleroma.Upload{
      name: "non-existant.jpg",
      content_type: "image/jpeg",
      path: Path.absname("test/fixtures/non-existant.jpg"),
      tempfile: Path.absname("test/fixtures/non-existant_tmp.jpg"),
      description: nil
    }

    assert Filter.Exiftool.ReadDescription.filter(uploads) ==
             {:ok, :filtered, uploads}
  end
end
