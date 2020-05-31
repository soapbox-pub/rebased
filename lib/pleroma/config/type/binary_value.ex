defmodule Pleroma.Config.Type.BinaryValue do
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
