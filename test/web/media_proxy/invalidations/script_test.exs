# Pleroma: A lightweight social networking server
# Copyright © 2017-2020 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.MediaProxy.Invalidation.ScriptTest do
  use ExUnit.Case
  alias Pleroma.Web.MediaProxy.Invalidation

  import ExUnit.CaptureLog

  setup do
    on_exit(fn -> Cachex.clear(:banned_urls_cache) end)
  end

  test "it logger error when script not found" do
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
end
