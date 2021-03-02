# Pleroma: A lightweight social networking server
# Copyright © 2017-2021 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.MediaProxy.InvalidationTest do
  use Pleroma.DataCase

  alias Pleroma.Web.MediaProxy.Invalidation

  import ExUnit.CaptureLog
  import Mock
  import Tesla.Mock

  setup do: clear_config([:media_proxy])

  describe "Invalidation.Http" do
    test "perform request to clear cache" do
      clear_config([:media_proxy, :enabled], false)
      clear_config([:media_proxy, :invalidation, :enabled], true)
      clear_config([:media_proxy, :invalidation, :provider], Invalidation.Http)

      clear_config([Invalidation.Http], method: :purge, headers: [{"x-refresh", 1}])
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
      clear_config([:media_proxy, :enabled], false)
      clear_config([:media_proxy, :invalidation, :enabled], true)
      clear_config([:media_proxy, :invalidation, :provider], Invalidation.Script)
      clear_config([Invalidation.Script], script_path: "purge-nginx")

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
