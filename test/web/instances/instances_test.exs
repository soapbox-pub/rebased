# Pleroma: A lightweight social networking server
# Copyright © 2017-2018 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.InstancesTest do
  alias Pleroma.Instances

  use Pleroma.DataCase

  setup_all do
    config_path = [:instance, :federation_reachability_timeout_days]
    initial_setting = Pleroma.Config.get(config_path)

    Pleroma.Config.put(config_path, 1)
    on_exit(fn -> Pleroma.Config.put(config_path, initial_setting) end)

    :ok
  end

  describe "reachable?/1" do
    test "returns `true` for host / url with unknown reachability status" do
      assert Instances.reachable?("unknown.site")
      assert Instances.reachable?("http://unknown.site")
    end

    test "returns `false` for host / url marked unreachable for at least `reachability_datetime_threshold()`" do
      host = "consistently-unreachable.name"
      Instances.set_consistently_unreachable(host)

      refute Instances.reachable?(host)
      refute Instances.reachable?("http://#{host}/path")
    end

    test "returns `true` for host / url marked unreachable for less than `reachability_datetime_threshold()`" do
      url = "http://eventually-unreachable.name/path"

      Instances.set_unreachable(url)

      assert Instances.reachable?(url)
      assert Instances.reachable?(URI.parse(url).host)
    end
  end

  describe "filter_reachable/1" do
    test "keeps only reachable elements of supplied list" do
      host = "consistently-unreachable.name"
      url1 = "http://eventually-unreachable.com/path"
      url2 = "http://domain.com/path"

      Instances.set_consistently_unreachable(host)
      Instances.set_unreachable(url1)

      assert [url1, url2] == Instances.filter_reachable([host, url1, url2])
    end
  end

  describe "set_reachable/1" do
    test "sets unreachable url or host reachable" do
      host = "domain.com"
      Instances.set_consistently_unreachable(host)
      refute Instances.reachable?(host)

      Instances.set_reachable(host)
      assert Instances.reachable?(host)
    end

    test "keeps reachable url or host reachable" do
      url = "https://site.name?q="
      assert Instances.reachable?(url)

      Instances.set_reachable(url)
      assert Instances.reachable?(url)
    end
  end

  describe "set_consistently_unreachable/1" do
    test "sets reachable url or host unreachable" do
      url = "http://domain.com?q="
      assert Instances.reachable?(url)

      Instances.set_consistently_unreachable(url)
      refute Instances.reachable?(url)
    end

    test "keeps unreachable url or host unreachable" do
      host = "site.name"
      Instances.set_consistently_unreachable(host)
      refute Instances.reachable?(host)

      Instances.set_consistently_unreachable(host)
      refute Instances.reachable?(host)
    end
  end
end
