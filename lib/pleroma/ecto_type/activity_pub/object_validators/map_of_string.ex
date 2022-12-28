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
          Map.put(acc, lang, value)

        _, acc ->
          acc
      end)

    {:ok, data}
  end

  def cast(_), do: :error

  def dump(data), do: {:ok, data}

  def load(data), do: {:ok, data}
end
