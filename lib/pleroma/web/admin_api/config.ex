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
    field(:group, :string)
    field(:value, :binary)

    timestamps()
  end

  @spec get_by_params(map()) :: Config.t() | nil
  def get_by_params(params), do: Repo.get_by(Config, params)

  @spec changeset(Config.t(), map()) :: Changeset.t()
  def changeset(config, params \\ %{}) do
    config
    |> cast(params, [:key, :group, :value])
    |> validate_required([:key, :group, :value])
    |> unique_constraint(:key, name: :config_group_key_index)
  end

  @spec create(map()) :: {:ok, Config.t()} | {:error, Changeset.t()}
  def create(params) do
    %Config{}
    |> changeset(Map.put(params, :value, transform(params[:value])))
    |> Repo.insert()
  end

  @spec update(Config.t(), map()) :: {:ok, Config} | {:error, Changeset.t()}
  def update(%Config{} = config, %{value: value}) do
    config
    |> change(value: transform(value))
    |> Repo.update()
  end

  @spec update_or_create(map()) :: {:ok, Config.t()} | {:error, Changeset.t()}
  def update_or_create(params) do
    with %Config{} = config <- Config.get_by_params(Map.take(params, [:group, :key])) do
      Config.update(config, params)
    else
      nil -> Config.create(params)
    end
  end

  @spec delete(map()) :: {:ok, Config.t()} | {:error, Changeset.t()}
  def delete(params) do
    with %Config{} = config <- Config.get_by_params(params) do
      Repo.delete(config)
    else
      nil -> {:error, "Config with params #{inspect(params)} not found"}
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

  defp do_convert(value) when is_tuple(value), do: %{"tuple" => do_convert(Tuple.to_list(value))}

  defp do_convert(value) when is_binary(value) or is_map(value) or is_number(value), do: value

  defp do_convert(value) when is_atom(value) do
    string = to_string(value)

    if String.starts_with?(string, "Elixir."),
      do: String.trim_leading(string, "Elixir."),
      else: value
  end

  @spec transform(any()) :: binary()
  def transform(%{"tuple" => _} = entity), do: :erlang.term_to_binary(do_transform(entity))

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

  defp do_transform(%{"tuple" => [k, values] = entity}) when length(entity) == 2 do
    {do_transform(k), do_transform(values)}
  end

  defp do_transform(%{"tuple" => values}) do
    Enum.reduce(values, {}, fn val, acc -> Tuple.append(acc, do_transform(val)) end)
  end

  defp do_transform(value) when is_map(value) do
    values = for {key, val} <- value, into: [], do: {String.to_atom(key), do_transform(val)}

    Enum.sort(values)
  end

  defp do_transform(value) when is_list(value) do
    Enum.map(value, &do_transform(&1))
  end

  defp do_transform(entity) when is_list(entity) and length(entity) == 1, do: hd(entity)

  defp do_transform(value) when is_binary(value) do
    String.trim(value)
    |> do_transform_string()
  end

  defp do_transform(value), do: value

  defp do_transform_string(value) when byte_size(value) == 0, do: nil

  defp do_transform_string(value) do
    cond do
      String.starts_with?(value, "Pleroma") or String.starts_with?(value, "Phoenix") ->
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
