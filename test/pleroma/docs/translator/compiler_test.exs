# Pleroma: A lightweight social networking server
# Copyright © 2017-2022 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Docs.Translator.CompilerTest do
  use ExUnit.Case, async: true

  alias Pleroma.Docs.Translator.Compiler

  @descriptions [
    %{
      label: "1",
      description: "2",
      children: [
        %{
          label: "3",
          description: "4"
        },
        %{
          label: "5",
          description: "6"
        }
      ]
    },
    %{
      label: "7",
      description: "8",
      children: [
        %{
          description: "9",
          children: [
            %{
              description: "10",
              children: [
                %{description: "11"},
                %{description: "12"}
              ]
            }
          ]
        },
        %{
          label: "13"
        }
      ]
    }
  ]

  describe "extract_strings/1" do
    test "it extracts all labels and descriptions" do
      strings = Compiler.extract_strings(@descriptions)
      assert length(strings) == 13
      assert Enum.all?(1..13, &(to_string(&1) in strings))
    end
  end
end
