# Pleroma: A lightweight social networking server
# Copyright © 2017-2020 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Upload.Filter.MogrifyTest do
  use Pleroma.DataCase
  import Mock

  alias Pleroma.Config
  alias Pleroma.Upload
  alias Pleroma.Upload.Filter

  clear_config([Filter.Mogrify, :args])

  test "apply mogrify filter" do
    Config.put([Filter.Mogrify, :args], [{"tint", "40"}])

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
        assert_receive {:apply_filter, {_, "tint", "40"}}, 4_000
      end)

    with_mock Mogrify,
      open: fn _f -> %Mogrify.Image{} end,
      custom: fn _m, _a -> :ok end,
      custom: fn m, a, o -> send(task.pid, {:apply_filter, {m, a, o}}) end,
      save: fn _f, _o -> :ok end do
      assert Filter.Mogrify.filter(upload) == :ok
    end

    Task.await(task)
  end
end
