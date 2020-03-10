# Pleroma: A lightweight social networking server
# Copyright © 2017-2020 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.HTTP.ConnectionTest do
  use ExUnit.Case, async: true
  use Pleroma.Tests.Helpers

  import ExUnit.CaptureLog

  alias Pleroma.Config
  alias Pleroma.HTTP.Connection

  describe "parse_host/1" do
    test "as atom to charlist" do
      assert Connection.parse_host(:localhost) == 'localhost'
    end

    test "as string to charlist" do
      assert Connection.parse_host("localhost.com") == 'localhost.com'
    end

    test "as string ip to tuple" do
      assert Connection.parse_host("127.0.0.1") == {127, 0, 0, 1}
    end
  end

  describe "parse_proxy/1" do
    test "ip with port" do
      assert Connection.parse_proxy("127.0.0.1:8123") == {:ok, {127, 0, 0, 1}, 8123}
    end

    test "host with port" do
      assert Connection.parse_proxy("localhost:8123") == {:ok, 'localhost', 8123}
    end

    test "as tuple" do
      assert Connection.parse_proxy({:socks4, :localhost, 9050}) ==
               {:ok, :socks4, 'localhost', 9050}
    end

    test "as tuple with string host" do
      assert Connection.parse_proxy({:socks5, "localhost", 9050}) ==
               {:ok, :socks5, 'localhost', 9050}
    end
  end

  describe "parse_proxy/1 errors" do
    test "ip without port" do
      capture_log(fn ->
        assert Connection.parse_proxy("127.0.0.1") == {:error, :invalid_proxy}
      end) =~ "parsing proxy fail \"127.0.0.1\""
    end

    test "host without port" do
      capture_log(fn ->
        assert Connection.parse_proxy("localhost") == {:error, :invalid_proxy}
      end) =~ "parsing proxy fail \"localhost\""
    end

    test "host with bad port" do
      capture_log(fn ->
        assert Connection.parse_proxy("localhost:port") == {:error, :invalid_proxy_port}
      end) =~ "parsing port in proxy fail \"localhost:port\""
    end

    test "ip with bad port" do
      capture_log(fn ->
        assert Connection.parse_proxy("127.0.0.1:15.9") == {:error, :invalid_proxy_port}
      end) =~ "parsing port in proxy fail \"127.0.0.1:15.9\""
    end

    test "as tuple without port" do
      capture_log(fn ->
        assert Connection.parse_proxy({:socks5, :localhost}) == {:error, :invalid_proxy}
      end) =~ "parsing proxy fail {:socks5, :localhost}"
    end

    test "with nil" do
      assert Connection.parse_proxy(nil) == nil
    end
  end

  describe "options/3" do
    clear_config([:http, :proxy_url])

    test "without proxy_url in config" do
      Config.delete([:http, :proxy_url])

      opts = Connection.options(%URI{})
      refute Keyword.has_key?(opts, :proxy)
    end

    test "parses string proxy host & port" do
      Config.put([:http, :proxy_url], "localhost:8123")

      opts = Connection.options(%URI{})
      assert opts[:proxy] == {'localhost', 8123}
    end

    test "parses tuple proxy scheme host and port" do
      Config.put([:http, :proxy_url], {:socks, 'localhost', 1234})

      opts = Connection.options(%URI{})
      assert opts[:proxy] == {:socks, 'localhost', 1234}
    end

    test "passed opts have more weight than defaults" do
      Config.put([:http, :proxy_url], {:socks5, 'localhost', 1234})

      opts = Connection.options(%URI{}, proxy: {'example.com', 4321})

      assert opts[:proxy] == {'example.com', 4321}
    end
  end

  describe "format_host/1" do
    test "with domain" do
      assert Connection.format_host("example.com") == 'example.com'
    end

    test "with idna domain" do
      assert Connection.format_host("ですexample.com") == 'xn--example-183fne.com'
    end

    test "with ipv4" do
      assert Connection.format_host("127.0.0.1") == '127.0.0.1'
    end

    test "with ipv6" do
      assert Connection.format_host("2a03:2880:f10c:83:face:b00c:0:25de") ==
               '2a03:2880:f10c:83:face:b00c:0:25de'
    end
  end
end
