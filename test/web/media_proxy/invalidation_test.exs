# Pleroma: A lightweight social networking server
# Copyright © 2017-2020 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.MediaProxy.InvalidationTest do
  use ExUnit.Case
  use Pleroma.Tests.Helpers

  alias Pleroma.Config
  alias Pleroma.Web.MediaProxy.Invalidation

  import ExUnit.CaptureLog
  import Mock
  import Tesla.Mock

  setup do: clear_config([:media_proxy])

  setup do
    on_exit(fn -> Cachex.clear(:banned_urls_cache) end)
  end

  describe "Invalidation.Http" do
    test "perform request to clear cache" do
      Config.put([:media_proxy, :enabled], false)
      Config.put([:media_proxy, :invalidation, :enabled], true)
      Config.put([:media_proxy, :invalidation, :provider], Invalidation.Http)

      Config.put([Invalidation.Http], method: :purge, headers: [{"x-refresh", 1}])
      image_url = "http://example.com/media/example.jpg"
      Pleroma.Web.MediaProxy.put_in_banned_urls(image_url)

      mock(fn
        %{
          method: :purge,
          url: "http://example.com/media/example.jpg",
          headers: [{"x-refresh", 1}]
        } ->
          %Tesla.Env{status: 200}
      end)

      assert capture_log(fn ->
               assert Pleroma.Web.MediaProxy.in_banned_urls(image_url)
               assert Invalidation.purge([image_url]) == {:ok, [image_url]}
               assert Pleroma.Web.MediaProxy.in_banned_urls(image_url)
             end) =~ "Running cache purge: [\"#{image_url}\"]"
    end
  end

  describe "Invalidation.Script" do
    test "run script to clear cache" do
      Config.put([:media_proxy, :enabled], false)
      Config.put([:media_proxy, :invalidation, :enabled], true)
      Config.put([:media_proxy, :invalidation, :provider], Invalidation.Script)
      Config.put([Invalidation.Script], script_path: "purge-nginx")

      image_url = "http://example.com/media/example.jpg"
      Pleroma.Web.MediaProxy.put_in_banned_urls(image_url)

      with_mocks [{System, [], [cmd: fn _, _ -> {"ok", 0} end]}] do
        assert capture_log(fn ->
                 assert Pleroma.Web.MediaProxy.in_banned_urls(image_url)
                 assert Invalidation.purge([image_url]) == {:ok, [image_url]}
                 assert Pleroma.Web.MediaProxy.in_banned_urls(image_url)
               end) =~ "Running cache purge: [\"#{image_url}\"]"
      end
    end
  end
end
