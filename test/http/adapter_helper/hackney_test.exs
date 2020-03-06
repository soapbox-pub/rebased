# Pleroma: A lightweight social networking server
# Copyright © 2017-2020 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.HTTP.AdapterHelper.HackneyTest do
  use ExUnit.Case, async: true
  use Pleroma.Tests.Helpers

  alias Pleroma.Config
  alias Pleroma.HTTP.AdapterHelper.Hackney

  setup_all do
    uri = URI.parse("http://domain.com")
    {:ok, uri: uri}
  end

  describe "options/2" do
    clear_config([:http, :adapter]) do
      Config.put([:http, :adapter], a: 1, b: 2)
    end

    test "add proxy and opts from config", %{uri: uri} do
      opts = Hackney.options([proxy: "localhost:8123"], uri)

      assert opts[:a] == 1
      assert opts[:b] == 2
      assert opts[:proxy] == "localhost:8123"
    end

    test "respect connection opts and no proxy", %{uri: uri} do
      opts = Hackney.options([a: 2, b: 1], uri)

      assert opts[:a] == 2
      assert opts[:b] == 1
      refute Keyword.has_key?(opts, :proxy)
    end

    test "add opts for https" do
      uri = URI.parse("https://domain.com")

      opts = Hackney.options(uri)

      assert opts[:ssl_options] == [
               partial_chain: &:hackney_connect.partial_chain/1,
               versions: [:tlsv1, :"tlsv1.1", :"tlsv1.2"],
               server_name_indication: 'domain.com'
             ]
    end
  end
end
