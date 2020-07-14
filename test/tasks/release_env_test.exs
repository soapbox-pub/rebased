# Pleroma: A lightweight social networking server
# Copyright © 2017-2020 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Mix.Tasks.Pleroma.ReleaseEnvTest do
  use ExUnit.Case
  import ExUnit.CaptureIO, only: [capture_io: 1]

  @path "config/pleroma.test.env"

  def do_clean do
    if File.exists?(@path) do
      File.rm_rf(@path)
    end
  end

  setup do
    do_clean()
    on_exit(fn -> do_clean() end)
    :ok
  end

  test "generate pleroma.env" do
    assert capture_io(fn ->
             Mix.Tasks.Pleroma.ReleaseEnv.run(["gen", "--path", @path, "--force"])
           end) =~ "The file generated"

    assert File.read!(@path) =~ "RELEASE_COOKIE="
  end
end
