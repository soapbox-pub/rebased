# Pleroma: A lightweight social networking server
# Copyright © 2017-2022 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Upload.Filter.MogrifyTest do
  use Pleroma.DataCase, async: true
  import Mox

  alias Pleroma.MogrifyMock
  alias Pleroma.StaticStubbedConfigMock, as: ConfigMock
  alias Pleroma.Upload.Filter

  setup :verify_on_exit!

  test "apply mogrify filter" do
    ConfigMock
    |> stub(:get!, fn [Filter.Mogrify, :args] -> [{"tint", "40"}] end)

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

    MogrifyMock
    |> expect(:open, fn _file -> %{} end)
    |> expect(:custom, fn _image, "tint", "40" -> %{} end)
    |> expect(:save, fn _image, [in_place: true] -> :ok end)

    assert Filter.Mogrify.filter(upload) == {:ok, :filtered}
  end
end
