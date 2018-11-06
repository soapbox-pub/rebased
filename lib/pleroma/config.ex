defmodule Pleroma.Config do
  def get([key]), do: get(key)

  def get([parent_key | keys]) do
    Application.get_env(:pleroma, parent_key)
    |> get_in(keys)
  end

  def get(key) do
    Application.get_env(:pleroma, key)
  end

  def put([key], value), do: put(key, value)

  def put([parent_key | keys], value) do
    parent =
      Application.get_env(:pleroma, parent_key)
      |> put_in(keys, value)

    Application.put_env(:pleroma, parent_key, parent)
  end

  def put(key, value) do
    Application.put_env(:pleroma, key, value)
  end
end
