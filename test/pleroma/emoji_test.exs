# Pleroma: A lightweight social networking server
# Copyright © 2017-2020 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.EmojiTest do
  use ExUnit.Case
  alias Pleroma.Emoji

  describe "is_unicode_emoji?/1" do
    test "tells if a string is an unicode emoji" do
      refute Emoji.is_unicode_emoji?("X")
      refute Emoji.is_unicode_emoji?("ね")

      assert Emoji.is_unicode_emoji?("☂")
      assert Emoji.is_unicode_emoji?("🥺")
      assert Emoji.is_unicode_emoji?("🤰")
      assert Emoji.is_unicode_emoji?("❤️")
    end
  end

  describe "get_all/0" do
    setup do
      emoji_list = Emoji.get_all()
      {:ok, emoji_list: emoji_list}
    end

    test "first emoji", %{emoji_list: emoji_list} do
      [emoji | _others] = emoji_list
      {code, %Emoji{file: path, tags: tags}} = emoji

      assert tuple_size(emoji) == 2
      assert is_binary(code)
      assert is_binary(path)
      assert is_list(tags)
    end

    test "random emoji", %{emoji_list: emoji_list} do
      emoji = Enum.random(emoji_list)
      {code, %Emoji{file: path, tags: tags}} = emoji

      assert tuple_size(emoji) == 2
      assert is_binary(code)
      assert is_binary(path)
      assert is_list(tags)
    end
  end
end
