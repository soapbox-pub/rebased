# Pleroma: A lightweight social networking server
# Copyright © 2017-2022 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.EctoType.ActivityPub.ObjectValidators.MapOfString do
  use Ecto.Type

  def type, do: :map

  def cast(object) when is_map(object) do
    data =
      object
      |> Enum.reduce(%{}, fn
        {lang, value}, acc when is_binary(lang) and is_binary(value) ->
          if is_good_locale_code?(lang) do
            Map.put(acc, lang, value)
          else
            acc
          end

        _, acc ->
          acc
      end)

    {:ok, data}
  end

  defp is_good_locale_code?(code) do
    code
    |> String.codepoints()
    |> Enum.all?(&valid_char?/1)
  end

  # [a-zA-Z0-9-]
  defp valid_char?(char) do
    ("a" <= char and char <= "z") or
      ("A" <= char and char <= "Z") or
      ("0" <= char and char <= "9") or
      char == "-"
  end

  def cast(_), do: :error

  def dump(data), do: {:ok, data}

  def load(data), do: {:ok, data}
end
