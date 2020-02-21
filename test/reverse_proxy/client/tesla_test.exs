# Pleroma: A lightweight social networking server
# Copyright © 2017-2019 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.ReverseProxy.Client.TeslaTest do
  use ExUnit.Case
  use Pleroma.Tests.Helpers
  alias Pleroma.ReverseProxy.Client
  @moduletag :integration

  clear_config_all(Pleroma.Gun.API) do
    Pleroma.Config.put(Pleroma.Gun.API, Pleroma.Gun)
  end

  setup do
    Application.put_env(:tesla, :adapter, Tesla.Adapter.Gun)

    on_exit(fn ->
      Application.put_env(:tesla, :adapter, Tesla.Mock)
    end)
  end

  test "get response body stream" do
    {:ok, status, headers, ref} =
      Client.Tesla.request(
        :get,
        "http://httpbin.org/stream-bytes/10",
        [{"accept", "application/octet-stream"}],
        "",
        []
      )

    assert status == 200
    assert headers != []

    {:ok, response, ref} = Client.Tesla.stream_body(ref)
    check_ref(ref)
    assert is_binary(response)
    assert byte_size(response) == 10

    assert :done == Client.Tesla.stream_body(ref)
    assert :ok = Client.Tesla.close(ref)
  end

  test "head response" do
    {:ok, status, headers} = Client.Tesla.request(:head, "https://httpbin.org/get", [], "")

    assert status == 200
    assert headers != []
  end

  test "get error response" do
    {:ok, status, headers, _body} =
      Client.Tesla.request(
        :get,
        "https://httpbin.org/status/500",
        [],
        ""
      )

    assert status == 500
    assert headers != []
  end

  describe "client error" do
    setup do
      adapter = Application.get_env(:tesla, :adapter)
      Application.put_env(:tesla, :adapter, Tesla.Adapter.Hackney)

      on_exit(fn -> Application.put_env(:tesla, :adapter, adapter) end)
      :ok
    end

    test "adapter doesn't support reading body in chunks" do
      assert_raise RuntimeError,
                   "Elixir.Tesla.Adapter.Hackney doesn't support reading body in chunks",
                   fn ->
                     Client.Tesla.request(
                       :get,
                       "http://httpbin.org/stream-bytes/10",
                       [{"accept", "application/octet-stream"}],
                       ""
                     )
                   end
    end
  end

  defp check_ref(%{pid: pid, stream: stream} = ref) do
    assert is_pid(pid)
    assert is_reference(stream)
    assert ref[:fin]
  end
end
