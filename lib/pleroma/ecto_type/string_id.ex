defmodule Pleroma.EctoType.StringId do
  @moduledoc """
  Stores the value as a number in the database, but represents it as a string.
  """
  use Ecto.Type

  def type, do: :id

  def cast(value) do
    {:ok, to_string(value)}
  end

  def load(value) do
    {:ok, to_string(value)}
  end

  def dump(value) do
    case Integer.parse(value) do
      {n, _} -> {:ok, n}
      _ -> {:error, value}
    end
  end
end
