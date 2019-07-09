defmodule Mix.Tasks.Pleroma.RobotsTxtTest do
  use ExUnit.Case, async: true
  alias Mix.Tasks.Pleroma.RobotsTxt

  test "creates new dir" do
    path = "test/fixtures/new_dir/"
    file_path = path <> "robots.txt"

    static_dir = Pleroma.Config.get([:instance, :static_dir])
    Pleroma.Config.put([:instance, :static_dir], path)

    on_exit(fn ->
      Pleroma.Config.put([:instance, :static_dir], static_dir)
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
    static_dir = Pleroma.Config.get([:instance, :static_dir])
    Pleroma.Config.put([:instance, :static_dir], path)

    on_exit(fn ->
      Pleroma.Config.put([:instance, :static_dir], static_dir)
      :ok = File.rm(file_path)
    end)

    RobotsTxt.run(["disallow_all"])

    assert File.exists?(file_path)
    {:ok, file} = File.read(file_path)

    assert file == "User-Agent: *\nDisallow: /\n"
  end
end
