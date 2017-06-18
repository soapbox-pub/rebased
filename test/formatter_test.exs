defmodule Pleroma.FormatterTest do
  alias Pleroma.Formatter
  use Pleroma.DataCase

  import Pleroma.Factory

  describe ".linkify" do
    test "turning urls into links" do
      text = "Hey, check out https://www.youtube.com/watch?v=8Zg1-TufF%20zY?x=1&y=2#blabla."

      expected = "Hey, check out <a href='https://www.youtube.com/watch?v=8Zg1-TufF%20zY?x=1&y=2#blabla'>https://www.youtube.com/watch?v=8Zg1-TufF%20zY?x=1&y=2#blabla</a>."

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

  test "it can parse mentions and return the relevant users" do
    text = "@gsimg According to @archaeme, that is @daggsy. Also hello @archaeme@archae.me"

    gsimg = insert(:user, %{nickname: "gsimg"})
    archaeme = insert(:user, %{nickname: "archaeme"})
    archaeme_remote = insert(:user, %{nickname: "archaeme@archae.me"})

    expected_result = [
      {"@gsimg", gsimg},
      {"@archaeme", archaeme},
      {"@archaeme@archae.me", archaeme_remote},
    ]

    assert Formatter.parse_mentions(text) == expected_result
  end
end
