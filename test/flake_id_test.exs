# Pleroma: A lightweight social networking server
# Copyright © 2017-2019 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.FlakeIdTest do
  use Pleroma.DataCase
  import Kernel, except: [to_string: 1]
  import Pleroma.FlakeId

  describe "fake flakes (compatibility with older serial integers)" do
    test "from_string/1" do
      fake_flake = <<0::integer-size(64), 42::integer-size(64)>>
      assert from_string("42") == fake_flake
      assert from_string(42) == fake_flake
    end

    test "zero or -1 is a null flake" do
      fake_flake = <<0::integer-size(128)>>
      assert from_string("0") == fake_flake
      assert from_string("-1") == fake_flake
    end

    test "to_string/1" do
      fake_flake = <<0::integer-size(64), 42::integer-size(64)>>
      assert to_string(fake_flake) == "42"
    end
  end

  test "ecto type behaviour" do
    flake = <<0, 0, 1, 104, 80, 229, 2, 235, 140, 22, 69, 201, 53, 210, 0, 0>>
    flake_s = "9eoozpwTul5mjSEDRI"

    assert cast(flake) == {:ok, flake_s}
    assert cast(flake_s) == {:ok, flake_s}

    assert load(flake) == {:ok, flake_s}
    assert load(flake_s) == {:ok, flake_s}

    assert dump(flake_s) == {:ok, flake}
    assert dump(flake) == {:ok, flake}
  end
end
