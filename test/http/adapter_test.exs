# Pleroma: A lightweight social networking server
# Copyright © 2017-2019 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.HTTP.AdapterTest do
  use ExUnit.Case, async: true

  alias Pleroma.HTTP.Adapter

  describe "domain_or_ip/1" do
    test "with domain" do
      assert Adapter.domain_or_ip("example.com") == {:domain, 'example.com'}
    end

    test "with idna domain" do
      assert Adapter.domain_or_ip("ですexample.com") == {:domain, 'xn--example-183fne.com'}
    end

    test "with ipv4" do
      assert Adapter.domain_or_ip("127.0.0.1") == {:ip, {127, 0, 0, 1}}
    end

    test "with ipv6" do
      assert Adapter.domain_or_ip("2a03:2880:f10c:83:face:b00c:0:25de") ==
               {:ip, {10_755, 10_368, 61_708, 131, 64_206, 45_068, 0, 9_694}}
    end
  end

  describe "domain_or_fallback/1" do
    test "with domain" do
      assert Adapter.domain_or_fallback("example.com") == 'example.com'
    end

    test "with idna domain" do
      assert Adapter.domain_or_fallback("ですexample.com") == 'xn--example-183fne.com'
    end

    test "with ipv4" do
      assert Adapter.domain_or_fallback("127.0.0.1") == '127.0.0.1'
    end

    test "with ipv6" do
      assert Adapter.domain_or_fallback("2a03:2880:f10c:83:face:b00c:0:25de") ==
               '2a03:2880:f10c:83:face:b00c:0:25de'
    end
  end

  describe "format_proxy/1" do
    test "with nil" do
      assert Adapter.format_proxy(nil) == nil
    end

    test "with string" do
      assert Adapter.format_proxy("127.0.0.1:8123") == {{127, 0, 0, 1}, 8123}
    end

    test "localhost with port" do
      assert Adapter.format_proxy("localhost:8123") == {'localhost', 8123}
    end

    test "tuple" do
      assert Adapter.format_proxy({:socks4, :localhost, 9050}) == {:socks4, 'localhost', 9050}
    end
  end
end
