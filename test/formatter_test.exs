defmodule Pleroma.FormatterTest do
  alias Pleroma.Formatter
  use Pleroma.DataCase

  describe ".linkify" do
    test "turning urls into links" do
      text = "Hey, check out https://www.youtube.com/watch?v=8Zg1-TufFzY."

      expected = "Hey, check out <a href='https://www.youtube.com/watch?v=8Zg1-TufFzY'>https://www.youtube.com/watch?v=8Zg1-TufFzY</a>."

      assert Formatter.linkify(text) == expected
    end
  end

  describe ".parse_tags" do
    test "parses tags in the text" do
      text = "Here's a #test. Maybe these are #working or not. What about #漢字? And #は｡"
      expected = [
        {"#test", "test"},
        {"#working", "working"},
        {"#漢字", "漢字"},
        {"#は", "は"}
      ]

      assert Formatter.parse_tags(text) == expected
    end
  end
end
