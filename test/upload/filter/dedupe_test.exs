# Pleroma: A lightweight social networking server
# Copyright © 2017-2020 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Upload.Filter.DedupeTest do
  use Pleroma.DataCase

  alias Pleroma.Upload
  alias Pleroma.Upload.Filter.Dedupe

  @shasum "e30397b58d226d6583ab5b8b3c5defb0c682bda5c31ef07a9f57c1c4986e3781"

  test "adds shasum" do
    File.cp!(
      "test/fixtures/image.jpg",
      "test/fixtures/image_tmp.jpg"
    )

    upload = %Upload{
      name: "an… image.jpg",
      content_type: "image/jpg",
      path: Path.absname("test/fixtures/image_tmp.jpg"),
      tempfile: Path.absname("test/fixtures/image_tmp.jpg")
    }

    assert {
             :ok,
             %Pleroma.Upload{id: @shasum, path: @shasum <> ".jpg"}
           } = Dedupe.filter(upload)
  end
end
