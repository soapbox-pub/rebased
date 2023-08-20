# Pleroma: A lightweight social networking server
# Copyright © 2017-2022 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.Utils.ColorsTest do
  use Pleroma.DataCase

  alias Pleroma.Web.Utils.Colors

  @base_color "#457d7b"

  describe "get_shades/1" do
    test "generates tints from a base color" do
      assert %{
               50 => "246, 249, 248",
               100 => "236, 242, 242",
               200 => "209, 223, 222",
               300 => "125, 164, 163",
               400 => "106, 151, 149",
               500 => "69, 125, 123",
               600 => "62, 113, 111",
               700 => "52, 94, 92",
               800 => "21, 38, 37",
               900 => "13, 24, 23"
             } == Colors.get_shades(@base_color)
    end

    test "uses soapbox blue if invalid color provided" do
      assert %{
               500 => "4, 130, 216"
             } = Colors.get_shades("255, 255, 127")
    end
  end

  test "shades_to_css/2" do
    result = Colors.shades_to_css("primary")
    assert String.contains?(result, "--color-primary-500: 4, 130, 216;")
  end
end
