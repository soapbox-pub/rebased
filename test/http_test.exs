# Pleroma: A lightweight social networking server
# Copyright © 2017-2018 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.HTTPTest do
  use ExUnit.Case
  use Pleroma.Tests.Helpers
  import Tesla.Mock
  alias Pleroma.HTTP

  setup do
    mock(fn
      %{
        method: :get,
        url: "http://example.com/hello",
        headers: [{"content-type", "application/json"}]
      } ->
        json(%{"my" => "data"})

      %{method: :get, url: "http://example.com/hello"} ->
        %Tesla.Env{status: 200, body: "hello"}

      %{method: :post, url: "http://example.com/world"} ->
        %Tesla.Env{status: 200, body: "world"}
    end)

    :ok
  end

  describe "get/1" do
    test "returns successfully result" do
      assert HTTP.get("http://example.com/hello") == {
               :ok,
               %Tesla.Env{status: 200, body: "hello"}
             }
    end
  end

  describe "get/2 (with headers)" do
    test "returns successfully result for json content-type" do
      assert HTTP.get("http://example.com/hello", [{"content-type", "application/json"}]) ==
               {
                 :ok,
                 %Tesla.Env{
                   status: 200,
                   body: "{\"my\":\"data\"}",
                   headers: [{"content-type", "application/json"}]
                 }
               }
    end
  end

  describe "post/2" do
    test "returns successfully result" do
      assert HTTP.post("http://example.com/world", "") == {
               :ok,
               %Tesla.Env{status: 200, body: "world"}
             }
    end
  end

  describe "connection pools" do
    @describetag :integration
    clear_config([Pleroma.Gun.API]) do
      Pleroma.Config.put([Pleroma.Gun.API], Pleroma.Gun)
    end

    test "gun" do
      adapter = Application.get_env(:tesla, :adapter)
      Application.put_env(:tesla, :adapter, Tesla.Adapter.Gun)

      on_exit(fn ->
        Application.put_env(:tesla, :adapter, adapter)
      end)

      options = [adapter: [pool: :federation]]

      assert {:ok, resp} = HTTP.get("https://httpbin.org/user-agent", [], options)

      assert resp.status == 200

      state = Pleroma.Pool.Connections.get_state(:gun_connections)
      assert state.conns["https:httpbin.org:443"]
    end
  end
end
