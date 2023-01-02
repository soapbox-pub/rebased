# Pleroma: A lightweight social networking server
# Copyright © 2017-2022 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Emoji.Combinations do
  # FE0F is the emoji variation sequence. It is used for fully-qualifying
  # emoji, and that includes emoji combinations.
  # This code generates combinations per emoji: for each FE0F, all possible
  # combinations of the character being removed or staying will be generated.
  # This is made as an attempt to find all partially-qualified and unqualified
  # versions of a fully-qualified emoji.
  # I have found *no cases* for which this would be a problem, after browsing
  # the entire emoji list in emoji-test.txt. This is safe, and, sadly, most
  # likely sane too.

  defp qualification_combinations(codepoints) do
    qualification_combinations([[]], codepoints)
  end

  defp qualification_combinations(acc, []), do: acc

  defp qualification_combinations(acc, ["\uFE0F" | tail]) do
    acc
    |> Enum.flat_map(fn x -> [x, x ++ ["\uFE0F"]] end)
    |> qualification_combinations(tail)
  end

  defp qualification_combinations(acc, [codepoint | tail]) do
    acc
    |> Enum.map(&Kernel.++(&1, [codepoint]))
    |> qualification_combinations(tail)
  end

  def variate_emoji_qualification(emoji) when is_binary(emoji) do
    emoji
    |> String.codepoints()
    |> qualification_combinations()
    |> Enum.map(&List.to_string/1)
  end

  def variate_emoji_qualification(emoji) when is_list(emoji) do
    emoji
    |> Enum.map(fn emoji -> {emoji, variate_emoji_qualification(emoji)} end)
  end
end
