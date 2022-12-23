# Pleroma: A lightweight social networking server
# Copyright © 2017-2022 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Docs.Translator.CompilerTest do
  use ExUnit.Case, async: true

  alias Pleroma.Docs.Translator.Compiler

  @descriptions [
    %{
      key: "1",
      label: "1",
      description: "2",
      children: [
        %{
          key: "3",
          label: "3",
          description: "4"
        },
        %{
          key: "5",
          label: "5",
          description: "6"
        }
      ]
    },
    %{
      key: "7",
      label: "7",
      description: "8",
      children: [
        %{
          key: "9",
          description: "9",
          children: [
            %{
              key: "10",
              description: "10",
              children: [
                %{key: "11", description: "11"},
                %{description: "12"}
              ]
            }
          ]
        },
        %{
          label: "13"
        }
      ]
    },
    %{
      group: "14",
      label: "14"
    },
    %{
      group: "15",
      key: "15",
      label: "15"
    },
    %{
      group: {":subgroup", "16"},
      label: "16"
    }
  ]

  describe "extract_strings/1" do
    test "it extracts all labels and descriptions" do
      strings = Compiler.extract_strings(@descriptions)
      assert length(strings) == 16

      assert {["1"], "label", "1"} in strings
      assert {["1"], "description", "2"} in strings
      assert {["1", "3"], "label", "3"} in strings
      assert {["1", "3"], "description", "4"} in strings
      assert {["1", "5"], "label", "5"} in strings
      assert {["1", "5"], "description", "6"} in strings
      assert {["7"], "label", "7"} in strings
      assert {["7"], "description", "8"} in strings
      assert {["7", "9"], "description", "9"} in strings
      assert {["7", "9", "10"], "description", "10"} in strings
      assert {["7", "9", "10", "11"], "description", "11"} in strings
      assert {["7", "9", "10", nil], "description", "12"} in strings
      assert {["7", nil], "label", "13"} in strings
      assert {["14"], "label", "14"} in strings
      assert {["15-15"], "label", "15"} in strings
      assert {["16"], "label", "16"} in strings
    end
  end
end
