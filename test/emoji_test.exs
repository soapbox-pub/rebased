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
      assert is_binary(tags)
    end

    test "random emoji", %{emoji_list: emoji_list} do
      emoji = Enum.random(emoji_list)
     {code, path, tags} = emoji

      assert tuple_size(emoji) == 3
      assert is_binary(code)
      assert is_binary(path)
      assert is_binary(tags)
    end
  end
end
