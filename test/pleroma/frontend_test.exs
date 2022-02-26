# Pleroma: A lightweight social networking server
# Copyright © 2017-2022 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.FrontendTest do
  use Pleroma.DataCase
  alias Pleroma.Frontend

  @dir "test/frontend_static_test"

  setup do
    File.mkdir_p!(@dir)
    clear_config([:instance, :static_dir], @dir)

    on_exit(fn ->
      File.rm_rf(@dir)
    end)
  end

  test "it downloads and unzips a known frontend" do
    clear_config([:frontends, :available], %{
      "pleroma" => %{
        "ref" => "fantasy",
        "name" => "pleroma",
        "build_url" => "http://gensokyo.2hu/builds/${ref}"
      }
    })

    Tesla.Mock.mock(fn %{url: "http://gensokyo.2hu/builds/fantasy"} ->
      %Tesla.Env{status: 200, body: File.read!("test/fixtures/tesla_mock/frontend_dist.zip")}
    end)

    Frontend.install("pleroma")

    assert File.exists?(Path.join([@dir, "frontends", "pleroma", "fantasy", "test.txt"]))
  end

  test "it also works given a file" do
    clear_config([:frontends, :available], %{
      "pleroma" => %{
        "ref" => "fantasy",
        "name" => "pleroma",
        "build_dir" => ""
      }
    })

    folder = Path.join([@dir, "frontends", "pleroma", "fantasy"])
    previously_existing = Path.join([folder, "temp"])
    File.mkdir_p!(folder)
    File.write!(previously_existing, "yey")
    assert File.exists?(previously_existing)

    Frontend.install("pleroma", file: "test/fixtures/tesla_mock/frontend.zip")

    assert File.exists?(Path.join([folder, "test.txt"]))
    refute File.exists?(previously_existing)
  end

  test "it downloads and unzips unknown frontends" do
    Tesla.Mock.mock(fn %{url: "http://gensokyo.2hu/madeup.zip"} ->
      %Tesla.Env{status: 200, body: File.read!("test/fixtures/tesla_mock/frontend.zip")}
    end)

    Frontend.install("unknown",
      ref: "baka",
      build_url: "http://gensokyo.2hu/madeup.zip",
      build_dir: ""
    )

    assert File.exists?(Path.join([@dir, "frontends", "unknown", "baka", "test.txt"]))
  end
end
