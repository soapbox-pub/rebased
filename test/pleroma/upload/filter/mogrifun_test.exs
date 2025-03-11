# Pleroma: A lightweight social networking server
# Copyright © 2017-2022 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Upload.Filter.MogrifunTest do
  use Pleroma.DataCase, async: true
  import Mox

  alias Pleroma.MogrifyMock
  alias Pleroma.Upload
  alias Pleroma.Upload.Filter

  test "apply mogrify filter" do
    File.cp!(
      "test/fixtures/image.jpg",
      "test/fixtures/image_tmp.jpg"
    )

    upload = %Upload{
      name: "an… image.jpg",
      content_type: "image/jpeg",
      path: Path.absname("test/fixtures/image_tmp.jpg"),
      tempfile: Path.absname("test/fixtures/image_tmp.jpg")
    }

    MogrifyMock
    |> stub(:open, fn _file -> %{} end)
    |> stub(:custom, fn _image, _action -> %{} end)
    |> stub(:custom, fn _image, _action, _options -> %{} end)
    |> stub(:save, fn _image, [in_place: true] -> :ok end)

    assert Filter.Mogrifun.filter(upload) == {:ok, :filtered}
  end
end
