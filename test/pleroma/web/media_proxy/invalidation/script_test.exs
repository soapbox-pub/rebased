# Pleroma: A lightweight social networking server
# Copyright © 2017-2022 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.MediaProxy.Invalidation.ScriptTest do
  use ExUnit.Case, async: true
  alias Pleroma.Web.MediaProxy.Invalidation

  import ExUnit.CaptureLog

  test "it logs error when script is not found" do
    assert capture_log(fn ->
             assert Invalidation.Script.purge(
                      ["http://example.com/media/example.jpg"],
                      script_path: "./example"
                    ) == {:error, "%ErlangError{original: :enoent}"}
           end) =~ "Error while cache purge: %ErlangError{original: :enoent}"

    capture_log(fn ->
      assert Invalidation.Script.purge(
               ["http://example.com/media/example.jpg"],
               []
             ) == {:error, "\"not found script path\""}
    end)
  end

  describe "url formatting" do
    setup do
      urls = [
        "https://bikeshed.party/media/foo.png",
        "http://safe.millennial.space/proxy/wheeeee.gif",
        "https://lain.com/proxy/mediafile.mp4?foo&bar=true",
        "http://localhost:4000/media/upload.jpeg"
      ]

      [urls: urls]
    end

    test "with invalid formatter", %{urls: urls} do
      assert urls == Invalidation.Script.maybe_format_urls(urls, nil)
    end

    test "with :htcacheclean formatter", %{urls: urls} do
      assert [
               "https://bikeshed.party:443/media/foo.png?",
               "http://safe.millennial.space:80/proxy/wheeeee.gif?",
               "https://lain.com:443/proxy/mediafile.mp4?foo&bar=true",
               "http://localhost:4000/media/upload.jpeg?"
             ] == Invalidation.Script.maybe_format_urls(urls, :htcacheclean)
    end
  end
end
