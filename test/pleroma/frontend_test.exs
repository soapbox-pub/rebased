# Pleroma: A lightweight social networking server
# Copyright © 2017-2021 Pleroma Authors <https://pleroma.social/>
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
    frontend = %Frontend{
      ref: "fantasy",
      name: "pleroma",
      build_url: "http://gensokyo.2hu/builds/${ref}"
    }

    clear_config([:frontends, :available], %{"pleroma" => Frontend.to_map(frontend)})

    Tesla.Mock.mock(fn %{url: "http://gensokyo.2hu/builds/fantasy"} ->
      %Tesla.Env{status: 200, body: File.read!("test/fixtures/tesla_mock/frontend_dist.zip")}
    end)

    Frontend.install(frontend)

    assert File.exists?(Path.join([@dir, "frontends", "pleroma", "fantasy", "test.txt"]))
  end

  test "it also works given a file" do
    frontend = %Frontend{
      ref: "fantasy",
      name: "pleroma",
      build_dir: "",
      file: "test/fixtures/tesla_mock/frontend.zip"
    }

    clear_config([:frontends, :available], %{"pleroma" => Frontend.to_map(frontend)})

    folder = Path.join([@dir, "frontends", "pleroma", "fantasy"])
    previously_existing = Path.join([folder, "temp"])
    File.mkdir_p!(folder)
    File.write!(previously_existing, "yey")
    assert File.exists?(previously_existing)

    Frontend.install(frontend)

    assert File.exists?(Path.join([folder, "test.txt"]))
    refute File.exists?(previously_existing)
  end

  test "it downloads and unzips unknown frontends" do
    frontend = %Frontend{
      ref: "baka",
      build_url: "http://gensokyo.2hu/madeup.zip",
      build_dir: ""
    }

    Tesla.Mock.mock(fn %{url: "http://gensokyo.2hu/madeup.zip"} ->
      %Tesla.Env{status: 200, body: File.read!("test/fixtures/tesla_mock/frontend.zip")}
    end)

    Frontend.install(frontend)

    assert File.exists?(Path.join([@dir, "frontends", "unknown", "baka", "test.txt"]))
  end

  test "merge/2 only overrides nil values" do
    fe1 = %Frontend{name: "pleroma"}
    fe2 = %Frontend{name: "soapbox", ref: "fantasy"}
    expected = %Frontend{name: "pleroma", ref: "fantasy"}
    assert Frontend.merge(fe1, fe2) == expected
  end

  test "validate!/1 raises if :ref isn't set" do
    fe = %Frontend{name: "pleroma"}
    assert_raise(RuntimeError, fn -> Frontend.validate!(fe) end)
  end

  test "validate!/1 returns the frontend" do
    fe = %Frontend{name: "pleroma", ref: "fantasy"}
    assert Frontend.validate!(fe) == fe
  end

  test "from_map/1 parses a map into a %Frontend{} struct" do
    map = %{"name" => "pleroma", "ref" => "fantasy"}
    expected = %Frontend{name: "pleroma", ref: "fantasy"}
    assert Frontend.from_map(map) == expected
  end

  test "to_map/1 returns the frontend as a map with string keys" do
    frontend = %Frontend{name: "pleroma", ref: "fantasy"}

    expected = %{
      "name" => "pleroma",
      "ref" => "fantasy",
      "build_dir" => nil,
      "build_url" => nil,
      "custom-http-headers" => nil,
      "file" => nil,
      "git" => nil
    }

    assert Frontend.to_map(frontend) == expected
  end

  test "parse_build_url/1 replaces ${ref}" do
    frontend = %Frontend{
      name: "pleroma",
      ref: "fantasy",
      build_url: "http://gensokyo.2hu/builds/${ref}"
    }

    expected = "http://gensokyo.2hu/builds/fantasy"
    assert Frontend.parse_build_url(frontend) == expected
  end

  test "dir/0 returns the frontend dir" do
    assert Frontend.dir() == "test/frontend_static_test/frontends"
  end

  test "get_named_frontend/1 returns a frontend from the config" do
    frontend = %Frontend{name: "pleroma", ref: "fantasy"}
    clear_config([:frontends, :available], %{"pleroma" => Frontend.to_map(frontend)})

    assert Frontend.get_named_frontend("pleroma") == frontend
  end

  describe "enable/2" do
    setup do
      clear_config(:configurable_from_database, true)
    end

    test "enables a primary frontend" do
      frontend = %Frontend{name: "soapbox", ref: "v1.2.3"}
      map = Frontend.to_map(frontend)

      clear_config([:frontends, :available], %{"soapbox" => map})
      Frontend.enable(frontend, :primary)

      assert Pleroma.Config.get([:frontends, :primary]) == map
    end

    test "enables an admin frontend" do
      frontend = %Frontend{name: "admin-fe", ref: "develop"}
      map = Frontend.to_map(frontend)

      clear_config([:frontends, :available], %{"admin-fe" => map})
      Frontend.enable(frontend, :admin)

      assert Pleroma.Config.get([:frontends, :admin]) == map
    end
  end
end
