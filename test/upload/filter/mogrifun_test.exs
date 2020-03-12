# Pleroma: A lightweight social networking server
# Copyright © 2017-2020 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Upload.Filter.MogrifunTest do
  use Pleroma.DataCase
  import Mock

  alias Pleroma.Upload
  alias Pleroma.Upload.Filter

  test "apply mogrify filter" do
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

    task =
      Task.async(fn ->
        assert_receive {:apply_filter, {}}, 4_000
      end)

    with_mocks([
      {Mogrify, [],
       [
         open: fn _f -> %Mogrify.Image{} end,
         custom: fn _m, _a -> send(task.pid, {:apply_filter, {}}) end,
         custom: fn _m, _a, _o -> send(task.pid, {:apply_filter, {}}) end,
         save: fn _f, _o -> :ok end
       ]}
    ]) do
      assert Filter.Mogrifun.filter(upload) == :ok
    end

    Task.await(task)
  end
end
