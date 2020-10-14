# Pleroma: A lightweight social networking server
# Copyright © 2017-2020 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.HTTP.AdapterHelperTest do
  use ExUnit.Case, async: true

  alias Pleroma.HTTP.AdapterHelper

  describe "format_proxy/1" do
    test "with nil" do
      assert AdapterHelper.format_proxy(nil) == nil
    end

    test "with string" do
      assert AdapterHelper.format_proxy("127.0.0.1:8123") == {{127, 0, 0, 1}, 8123}
    end

    test "localhost with port" do
      assert AdapterHelper.format_proxy("localhost:8123") == {'localhost', 8123}
    end

    test "tuple" do
      assert AdapterHelper.format_proxy({:socks4, :localhost, 9050}) ==
               {:socks4, 'localhost', 9050}
    end
  end
end
