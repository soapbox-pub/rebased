# Pleroma: A lightweight social networking server
# Copyright © 2017-2018 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.CommonAPI.UtilsTest do
  alias Pleroma.Builders.UserBuilder
  alias Pleroma.Object
  alias Pleroma.Web.CommonAPI.Utils
  alias Pleroma.Web.Endpoint
  use Pleroma.DataCase

  test "it adds attachment links to a given text and attachment set" do
    name =
      "Sakura%20Mana%20%E2%80%93%20Turned%20on%20by%20a%20Senior%20OL%20with%20a%20Temptating%20Tight%20Skirt-s%20Full%20Hipline%20and%20Panty%20Shot-%20Beautiful%20Thick%20Thighs-%20and%20Erotic%20Ass-%20-2015-%20--%20Oppaitime%208-28-2017%206-50-33%20PM.png"

    attachment = %{
      "url" => [%{"href" => name}]
    }

    res = Utils.add_attachments("", [attachment])

    assert res ==
             "<br><a href=\"#{name}\" class='attachment'>Sakura Mana – Turned on by a Se…</a>"
  end

  describe "it confirms the password given is the current users password" do
    test "incorrect password given" do
      {:ok, user} = UserBuilder.insert()

      assert Utils.confirm_current_password(user, "") == {:error, "Invalid password."}
    end

    test "correct password given" do
      {:ok, user} = UserBuilder.insert()
      assert Utils.confirm_current_password(user, "test") == {:ok, user}
    end
  end

  test "parses emoji from name and bio" do
    {:ok, user} = UserBuilder.insert(%{name: ":blank:", bio: ":firefox:"})

    expected = [
      %{
        "type" => "Emoji",
        "icon" => %{"type" => "Image", "url" => "#{Endpoint.url()}/emoji/Firefox.gif"},
        "name" => ":firefox:"
      },
      %{
        "type" => "Emoji",
        "icon" => %{
          "type" => "Image",
          "url" => "#{Endpoint.url()}/emoji/blank.png"
        },
        "name" => ":blank:"
      }
    ]

    assert expected == Utils.emoji_from_profile(user)
  end

  describe "format_input/3" do
    test "works for bare text/plain" do
      text = "hello world!"
      expected = "hello world!"

      {output, [], []} = Utils.format_input(text, "text/plain")

      assert output == expected

      text = "hello world!\n\nsecond paragraph!"
      expected = "hello world!<br><br>second paragraph!"

      {output, [], []} = Utils.format_input(text, "text/plain")

      assert output == expected
    end

    test "works for bare text/html" do
      text = "<p>hello world!</p>"
      expected = "<p>hello world!</p>"

      {output, [], []} = Utils.format_input(text, "text/html")

      assert output == expected

      text = "<p>hello world!</p>\n\n<p>second paragraph</p>"
      expected = "<p>hello world!</p>\n\n<p>second paragraph</p>"

      {output, [], []} = Utils.format_input(text, "text/html")

      assert output == expected
    end

    test "works for bare text/markdown" do
      text = "**hello world**"
      expected = "<p><strong>hello world</strong></p>\n"

      {output, [], []} = Utils.format_input(text, "text/markdown")

      assert output == expected

      text = "**hello world**\n\n*another paragraph*"
      expected = "<p><strong>hello world</strong></p>\n<p><em>another paragraph</em></p>\n"

      {output, [], []} = Utils.format_input(text, "text/markdown")

      assert output == expected

      text = """
      > cool quote

      by someone
      """

      expected = "<blockquote><p>cool quote</p>\n</blockquote>\n<p>by someone</p>\n"

      {output, [], []} = Utils.format_input(text, "text/markdown")

      assert output == expected
    end

    test "works for bare text/bbcode" do
      text = "[b]hello world[/b]"
      expected = "<strong>hello world</strong>"

      {output, [], []} = Utils.format_input(text, "text/bbcode")

      assert output == expected

      text = "[b]hello world![/b]\n\nsecond paragraph!"
      expected = "<strong>hello world!</strong><br>\n<br>\nsecond paragraph!"

      {output, [], []} = Utils.format_input(text, "text/bbcode")

      assert output == expected

      text = "[b]hello world![/b]\n\n<strong>second paragraph!</strong>"

      expected =
        "<strong>hello world!</strong><br>\n<br>\n&lt;strong&gt;second paragraph!&lt;/strong&gt;"

      {output, [], []} = Utils.format_input(text, "text/bbcode")

      assert output == expected
    end

    test "works for text/markdown with mentions" do
      {:ok, user} =
        UserBuilder.insert(%{nickname: "user__test", ap_id: "http://foo.com/user__test"})

      text = "**hello world**\n\n*another @user__test and @user__test google.com paragraph*"

      expected =
        "<p><strong>hello world</strong></p>\n<p><em>another <span class=\"h-card\"><a data-user=\"#{
          user.id
        }\" class=\"u-url mention\" href=\"http://foo.com/user__test\">@<span>user__test</span></a></span> and <span class=\"h-card\"><a data-user=\"#{
          user.id
        }\" class=\"u-url mention\" href=\"http://foo.com/user__test\">@<span>user__test</span></a></span> <a href=\"http://google.com\">google.com</a> paragraph</em></p>\n"

      {output, _, _} = Utils.format_input(text, "text/markdown")

      assert output == expected
    end
  end

  describe "context_to_conversation_id" do
    test "creates a mapping object" do
      conversation_id = Utils.context_to_conversation_id("random context")
      object = Object.get_by_ap_id("random context")

      assert conversation_id == object.id
    end

    test "returns an existing mapping for an existing object" do
      {:ok, object} = Object.context_mapping("random context") |> Repo.insert()
      conversation_id = Utils.context_to_conversation_id("random context")

      assert conversation_id == object.id
    end
  end

  describe "formats date to asctime" do
    test "when date is in ISO 8601 format" do
      date = DateTime.utc_now() |> DateTime.to_iso8601()

      expected =
        date
        |> DateTime.from_iso8601()
        |> elem(1)
        |> Calendar.Strftime.strftime!("%a %b %d %H:%M:%S %z %Y")

      assert Utils.date_to_asctime(date) == expected
    end

    test "when date is a binary in wrong format" do
      date = DateTime.utc_now()

      expected = ""

      assert Utils.date_to_asctime(date) == expected
    end

    test "when date is a Unix timestamp" do
      date = DateTime.utc_now() |> DateTime.to_unix()

      expected = ""

      assert Utils.date_to_asctime(date) == expected
    end

    test "when date is nil" do
      expected = ""

      assert Utils.date_to_asctime(nil) == expected
    end
  end
end
