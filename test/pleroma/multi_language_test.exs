# Pleroma: A lightweight social networking server
# Copyright © 2017-2022 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.MultiLanguageTest do
  use Pleroma.DataCase, async: true

  alias Pleroma.MultiLanguage

  describe "map_to_str" do
    setup do
      %{
        data: %{
          "en-US" => "mew",
          "en-GB" => "meow"
        }
      }
    end

    test "single line", %{data: data} do
      assert MultiLanguage.map_to_str(data) == "[en-GB] meow | [en-US] mew"
    end

    test "multi line", %{data: data} do
      assert MultiLanguage.map_to_str(data, multiline: true) ==
               "<div lang=\"en-GB\">meow</div><br><hr><br><div lang=\"en-US\">mew</div>"
    end

    test "only one language" do
      data = %{"some" => "foo"}
      assert MultiLanguage.map_to_str(data) == "foo"
      assert MultiLanguage.map_to_str(data, multiline: true) == "foo"
    end

    test "resistent to tampering" do
      data = %{
        "en-US" => "mew {code} {content}",
        "en-GB" => "meow {code} {content}"
      }

      assert MultiLanguage.map_to_str(data) ==
               "[en-GB] meow {code} {content} | [en-US] mew {code} {content}"
    end
  end

  describe "str_to_map" do
    test "" do
      assert MultiLanguage.str_to_map("foo") == %{"und" => "foo"}
    end
  end
end
