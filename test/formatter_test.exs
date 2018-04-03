defmodule Pleroma.FormatterTest do
  alias Pleroma.Formatter
  use Pleroma.DataCase

  import Pleroma.Factory

  describe ".add_hashtag_links" do
    test "turns hashtags into links" do
      text = "I love #cofe and #2hu"

      expected_text =
        "I love <a href='http://localhost:4001/tag/cofe' rel='tag'>#cofe</a> and <a href='http://localhost:4001/tag/2hu' rel='tag'>#2hu</a>"

      tags = Formatter.parse_tags(text)

      assert expected_text ==
               Formatter.add_hashtag_links({[], text}, tags) |> Formatter.finalize()
    end
  end

  describe ".add_links" do
    test "turning urls into links" do
      text = "Hey, check out https://www.youtube.com/watch?v=8Zg1-TufF%20zY?x=1&y=2#blabla."

      expected =
        "Hey, check out <a href='https://www.youtube.com/watch?v=8Zg1-TufF%20zY?x=1&y=2#blabla'>https://www.youtube.com/watch?v=8Zg1-TufF%20zY?x=1&y=2#blabla</a>."

      assert Formatter.add_links({[], text}) |> Formatter.finalize() == expected

      text = "https://mastodon.social/@lambadalambda"

      expected =
        "<a href='https://mastodon.social/@lambadalambda'>https://mastodon.social/@lambadalambda</a>"

      assert Formatter.add_links({[], text}) |> Formatter.finalize() == expected

      text = "@lambadalambda"
      expected = "@lambadalambda"

      assert Formatter.add_links({[], text}) |> Formatter.finalize() == expected

      text = "http://www.cs.vu.nl/~ast/intel/"
      expected = "<a href='http://www.cs.vu.nl/~ast/intel/'>http://www.cs.vu.nl/~ast/intel/</a>"

      assert Formatter.add_links({[], text}) |> Formatter.finalize() == expected

      text = "https://forum.zdoom.org/viewtopic.php?f=44&t=57087"

      expected =
        "<a href='https://forum.zdoom.org/viewtopic.php?f=44&t=57087'>https://forum.zdoom.org/viewtopic.php?f=44&t=57087</a>"

      assert Formatter.add_links({[], text}) |> Formatter.finalize() == expected

      text = "https://en.wikipedia.org/wiki/Sophia_(Gnosticism)#Mythos_of_the_soul"

      expected =
        "<a href='https://en.wikipedia.org/wiki/Sophia_(Gnosticism)#Mythos_of_the_soul'>https://en.wikipedia.org/wiki/Sophia_(Gnosticism)#Mythos_of_the_soul</a>"

      assert Formatter.add_links({[], text}) |> Formatter.finalize() == expected
    end
  end

  describe "add_user_links" do
    test "gives a replacement for user links" do
      text = "@gsimg According to @archaeme, that is @daggsy. Also hello @archaeme@archae.me"
      gsimg = insert(:user, %{nickname: "gsimg"})

      archaeme =
        insert(:user, %{
          nickname: "archaeme",
          info: %{"source_data" => %{"url" => "https://archeme/@archaeme"}}
        })

      archaeme_remote = insert(:user, %{nickname: "archaeme@archae.me"})

      mentions = Pleroma.Formatter.parse_mentions(text)

      {subs, text} = Formatter.add_user_links({[], text}, mentions)

      assert length(subs) == 3
      Enum.each(subs, fn {uuid, _} -> assert String.contains?(text, uuid) end)

      expected_text =
        "<span><a href='#{gsimg.ap_id}'>@<span>gsimg</span></a></span> According to <span><a href='#{
          "https://archeme/@archaeme"
        }'>@<span>archaeme</span></a></span>, that is @daggsy. Also hello <span><a href='#{
          archaeme_remote.ap_id
        }'>@<span>archaeme</span></a></span>"

      assert expected_text == Formatter.finalize({subs, text})
    end
  end

  describe ".parse_tags" do
    test "parses tags in the text" do
      text = "Here's a #Test. Maybe these are #working or not. What about #漢字? And #は｡"

      expected = [
        {"#Test", "test"},
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
      {"@archaeme@archae.me", archaeme_remote}
    ]

    assert Formatter.parse_mentions(text) == expected_result
  end

  test "it adds cool emoji" do
    text = "I love :moominmamma:"

    expected_result =
      "I love <img height='32px' width='32px' alt='moominmamma' title='moominmamma' src='/finmoji/128px/moominmamma-128.png' />"

    assert Formatter.emojify(text) == expected_result
  end

  test "it returns the emoji used in the text" do
    text = "I love :moominmamma:"

    assert Formatter.get_emoji(text) == [{"moominmamma", "/finmoji/128px/moominmamma-128.png"}]
  end
end
