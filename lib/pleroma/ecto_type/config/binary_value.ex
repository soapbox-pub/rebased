# Pleroma: A lightweight social networking server
# Copyright © 2017-2022 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.EctoType.Config.BinaryValue do
  use Ecto.Type

  def type, do: :term

  def cast(value) when is_binary(value) do
    if String.valid?(value) do
      {:ok, value}
    else
      {:ok, :erlang.binary_to_term(value)}
    end
  end

  def cast(value), do: {:ok, value}

  def load(value) when is_binary(value) do
    {:ok, :erlang.binary_to_term(value)}
  end

  def dump(value) do
    {:ok, :erlang.term_to_binary(value)}
  end
end
