# Pleroma: A lightweight social networking server
# Copyright © 2017-2019 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.AdminAPI.Config do
  use Ecto.Schema
  import Ecto.Changeset
  alias __MODULE__
  alias Pleroma.Repo

  @type t :: %__MODULE__{}

  schema "config" do
    field(:key, :string)
    field(:value, :binary)

    timestamps()
  end

  @spec get_by_key(String.t()) :: Config.t() | nil
  def get_by_key(key), do: Repo.get_by(Config, key: key)

  @spec changeset(Config.t(), map()) :: Changeset.t()
  def changeset(config, params \\ %{}) do
    config
    |> cast(params, [:key, :value])
    |> validate_required([:key, :value])
    |> unique_constraint(:key)
  end

  @spec create(map()) :: {:ok, Config.t()} | {:error, Changeset.t()}
  def create(%{key: key, value: value}) do
    %Config{}
    |> changeset(%{key: key, value: transform(value)})
    |> Repo.insert()
  end

  @spec update(Config.t(), map()) :: {:ok, Config} | {:error, Changeset.t()}
  def update(%Config{} = config, %{value: value}) do
    config
    |> change(value: transform(value))
    |> Repo.update()
  end

  @spec update_or_create(map()) :: {:ok, Config.t()} | {:error, Changeset.t()}
  def update_or_create(%{key: key} = params) do
    with %Config{} = config <- Config.get_by_key(key) do
      Config.update(config, params)
    else
      nil -> Config.create(params)
    end
  end

  @spec delete(String.t()) :: {:ok, Config.t()} | {:error, Changeset.t()}
  def delete(key) do
    with %Config{} = config <- Config.get_by_key(key) do
      Repo.delete(config)
    else
      nil -> {:error, "Config with key #{key} not found"}
    end
  end

  @spec from_binary(binary()) :: term()
  def from_binary(value), do: :erlang.binary_to_term(value)

  @spec from_binary_to_map(binary()) :: any()
  def from_binary_to_map(binary) do
    from_binary(binary)
    |> do_convert()
  end

  defp do_convert([{k, v}] = value) when is_list(value) and length(value) == 1,
    do: %{k => do_convert(v)}

  defp do_convert(values) when is_list(values), do: for(val <- values, do: do_convert(val))

  defp do_convert({k, v} = value) when is_tuple(value),
    do: %{k => do_convert(v)}

  defp do_convert(value) when is_binary(value) or is_atom(value) or is_map(value),
    do: value

  @spec transform(any()) :: binary()
  def transform(entity) when is_map(entity) do
    tuples =
      for {k, v} <- entity,
          into: [],
          do: {if(is_atom(k), do: k, else: String.to_atom(k)), do_transform(v)}

    Enum.reject(tuples, fn {_k, v} -> is_nil(v) end)
    |> Enum.sort()
    |> :erlang.term_to_binary()
  end

  def transform(entity) when is_list(entity) do
    list = Enum.map(entity, &do_transform(&1))
    :erlang.term_to_binary(list)
  end

  def transform(entity), do: :erlang.term_to_binary(entity)

  defp do_transform(%Regex{} = value) when is_map(value), do: value

  defp do_transform(value) when is_map(value) do
    values =
      for {key, val} <- value,
          into: [],
          do: {String.to_atom(key), do_transform(val)}

    Enum.sort(values)
  end

  defp do_transform(value) when is_list(value) do
    Enum.map(value, &do_transform(&1))
  end

  defp do_transform(entity) when is_list(entity) and length(entity) == 1, do: hd(entity)

  defp do_transform(value) when is_binary(value) do
    value = String.trim(value)

    case String.length(value) do
      0 ->
        nil

      _ ->
        cond do
          String.starts_with?(value, "Pleroma") ->
            String.to_existing_atom("Elixir." <> value)

          String.starts_with?(value, ":") ->
            String.replace(value, ":", "") |> String.to_existing_atom()

          String.starts_with?(value, "i:") ->
            String.replace(value, "i:", "") |> String.to_integer()

          true ->
            value
        end
    end
  end

  defp do_transform(value), do: value
end
