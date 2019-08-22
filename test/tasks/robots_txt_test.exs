# Pleroma: A lightweight social networking server
# Copyright © 2017-2019 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Mix.Tasks.Pleroma.RobotsTxtTest do
  use ExUnit.Case
  use Pleroma.Tests.Helpers
  alias Mix.Tasks.Pleroma.RobotsTxt

  clear_config([:instance, :static_dir])

  test "creates new dir" do
    path = "test/fixtures/new_dir/"
    file_path = path <> "robots.txt"
    Pleroma.Config.put([:instance, :static_dir], path)

    on_exit(fn ->
      {:ok, ["test/fixtures/new_dir/", "test/fixtures/new_dir/robots.txt"]} = File.rm_rf(path)
    end)

    RobotsTxt.run(["disallow_all"])

    assert File.exists?(file_path)
    {:ok, file} = File.read(file_path)

    assert file == "User-Agent: *\nDisallow: /\n"
  end

  test "to existance folder" do
    path = "test/fixtures/"
    file_path = path <> "robots.txt"
    Pleroma.Config.put([:instance, :static_dir], path)

    on_exit(fn ->
      :ok = File.rm(file_path)
    end)

    RobotsTxt.run(["disallow_all"])

    assert File.exists?(file_path)
    {:ok, file} = File.read(file_path)

    assert file == "User-Agent: *\nDisallow: /\n"
  end
end
