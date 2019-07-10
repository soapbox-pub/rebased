# Pleroma: A lightweight social networking server
# Copyright © 2017-2019 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.EmojiTest do
  use ExUnit.Case, async: true
  alias Pleroma.Emoji

  describe "get_all/0" do
    setup do
      emoji_list = Emoji.get_all()
      {:ok, emoji_list: emoji_list}
    end

    test "first emoji", %{emoji_list: emoji_list} do
      [emoji | _others] = emoji_list
      {code, path, tags} = emoji

      assert tuple_size(emoji) == 3
      assert is_binary(code)
      assert is_binary(path)
      assert is_list(tags)
    end

    test "random emoji", %{emoji_list: emoji_list} do
      emoji = Enum.random(emoji_list)
      {code, path, tags} = emoji

      assert tuple_size(emoji) == 3
      assert is_binary(code)
      assert is_binary(path)
      assert is_list(tags)
    end
  end

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
        |> Emoji.match_extra("/emoji/custom/first_file.png")
        |> to_string()

      assert group == "list of files"
    end

    test "config with wildcard folder", %{groups: groups} do
      group =
        groups
        |> Emoji.match_extra("/emoji/custom/some_folder/file.png")
        |> to_string()

      assert group == "wildcard folder"
    end

    test "config with wildcard folder and subfolders", %{groups: groups} do
      group =
        groups
        |> Emoji.match_extra("/emoji/custom/some_folder/another_folder/file.png")
        |> to_string()

      assert group == "wildcard folder"
    end

    test "config with wildcard files", %{groups: groups} do
      group =
        groups
        |> Emoji.match_extra("/emoji/custom/folder/some_file.png")
        |> to_string()

      assert group == "wildcard files"
    end

    test "config with wildcard files and subfolders", %{groups: groups} do
      group =
        groups
        |> Emoji.match_extra("/emoji/custom/folder/another_folder/some_file.png")
        |> to_string()

      assert group == "wildcard files"
    end

    test "config for special file", %{groups: groups} do
      group =
        groups
        |> Emoji.match_extra("/emoji/custom/special.png")
        |> to_string()

      assert group == "special file"
    end

    test "no mathing returns nil", %{groups: groups} do
      group =
        groups
        |> Emoji.match_extra("/emoji/some_undefined.png")

      refute group
    end
  end
end
