# Pleroma: A lightweight social networking server
# Copyright © 2017-2020 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Emoji.LoaderTest do
  use ExUnit.Case, async: true
  alias Pleroma.Emoji.Loader

  describe "match_extra/2" do
    setup do
      groups = [
        "list of files": ["/emoji/custom/first_file.png", "/emoji/custom/second_file.png"],
        "wildcard folder": "/emoji/custom/*/file.png",
        "wildcard files": "/emoji/custom/folder/*.png",
        "special file": "/emoji/custom/special.png"
      ]

      {:ok, groups: groups}
    end

    test "config for list of files", %{groups: groups} do
      group =
        groups
        |> Loader.match_extra("/emoji/custom/first_file.png")
        |> to_string()

      assert group == "list of files"
    end

    test "config with wildcard folder", %{groups: groups} do
      group =
        groups
        |> Loader.match_extra("/emoji/custom/some_folder/file.png")
        |> to_string()

      assert group == "wildcard folder"
    end

    test "config with wildcard folder and subfolders", %{groups: groups} do
      group =
        groups
        |> Loader.match_extra("/emoji/custom/some_folder/another_folder/file.png")
        |> to_string()

      assert group == "wildcard folder"
    end

    test "config with wildcard files", %{groups: groups} do
      group =
        groups
        |> Loader.match_extra("/emoji/custom/folder/some_file.png")
        |> to_string()

      assert group == "wildcard files"
    end

    test "config with wildcard files and subfolders", %{groups: groups} do
      group =
        groups
        |> Loader.match_extra("/emoji/custom/folder/another_folder/some_file.png")
        |> to_string()

      assert group == "wildcard files"
    end

    test "config for special file", %{groups: groups} do
      group =
        groups
        |> Loader.match_extra("/emoji/custom/special.png")
        |> to_string()

      assert group == "special file"
    end

    test "no mathing returns nil", %{groups: groups} do
      group =
        groups
        |> Loader.match_extra("/emoji/some_undefined.png")

      refute group
    end
  end
end
