# Pleroma: A lightweight social networking server
# Copyright © 2017-2021 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.HTTP.AdapterHelper.GunTest do
  use ExUnit.Case
  use Pleroma.Tests.Helpers

  import Mox

  alias Pleroma.HTTP.AdapterHelper.Gun

  setup :verify_on_exit!

  describe "options/1" do
    setup do: clear_config([:http, :adapter], a: 1, b: 2)

    test "https url with default port" do
      uri = URI.parse("https://example.com")

      opts = Gun.options([receive_conn: false], uri)
      assert opts[:certificates_verification]
    end

    test "https ipv4 with default port" do
      uri = URI.parse("https://127.0.0.1")

      opts = Gun.options([receive_conn: false], uri)
      assert opts[:certificates_verification]
    end

    test "https ipv6 with default port" do
      uri = URI.parse("https://[2a03:2880:f10c:83:face:b00c:0:25de]")

      opts = Gun.options([receive_conn: false], uri)
      assert opts[:certificates_verification]
    end

    test "https url with non standart port" do
      uri = URI.parse("https://example.com:115")

      opts = Gun.options([receive_conn: false], uri)

      assert opts[:certificates_verification]
    end

    test "merges with defaul http adapter config" do
      defaults = Gun.options([receive_conn: false], URI.parse("https://example.com"))
      assert Keyword.has_key?(defaults, :a)
      assert Keyword.has_key?(defaults, :b)
    end

    test "parses string proxy host & port" do
      clear_config([:http, :proxy_url], "localhost:8123")

      uri = URI.parse("https://some-domain.com")
      opts = Gun.options([receive_conn: false], uri)
      assert opts[:proxy] == {'localhost', 8123}
    end

    test "parses tuple proxy scheme host and port" do
      clear_config([:http, :proxy_url], {:socks, 'localhost', 1234})

      uri = URI.parse("https://some-domain.com")
      opts = Gun.options([receive_conn: false], uri)
      assert opts[:proxy] == {:socks, 'localhost', 1234}
    end

    test "passed opts have more weight than defaults" do
      clear_config([:http, :proxy_url], {:socks5, 'localhost', 1234})
      uri = URI.parse("https://some-domain.com")
      opts = Gun.options([receive_conn: false, proxy: {'example.com', 4321}], uri)

      assert opts[:proxy] == {'example.com', 4321}
    end
  end
end
