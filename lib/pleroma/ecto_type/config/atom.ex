# Pleroma: A lightweight social networking server
# Copyright © 2017-2021 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.EctoType.Config.Atom do
  use Ecto.Type

  def type, do: :atom

  def cast(key) when is_atom(key) do
    {:ok, key}
  end

  def cast(key) when is_binary(key) do
    {:ok, Pleroma.ConfigDB.string_to_elixir_types(key)}
  end

  def cast(_), do: :error

  def load(key) do
    {:ok, Pleroma.ConfigDB.string_to_elixir_types(key)}
  end

  def dump(key) when is_atom(key), do: {:ok, inspect(key)}
  def dump(_), do: :error
end
