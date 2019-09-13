# Pleroma: A lightweight social networking server
# Copyright © 2017-2019 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.AdminAPI.Config do
  use Ecto.Schema
  import Ecto.Changeset
  import Pleroma.Web.Gettext
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
    with %Config{} = config <- Config.get_by_params(Map.delete(params, :subkeys)) do
      if params[:subkeys] do
        updated_value =
          Keyword.drop(
            :erlang.binary_to_term(config.value),
            Enum.map(params[:subkeys], &do_transform_string(&1))
          )

        Config.update(config, %{value: updated_value})
      else
        Repo.delete(config)
        {:ok, nil}
      end
    else
      nil ->
        err =
          dgettext("errors", "Config with params %{params} not found", params: inspect(params))

        {:error, err}
    end
  end

  @spec from_binary(binary()) :: term()
  def from_binary(binary), do: :erlang.binary_to_term(binary)

  @spec from_binary_with_convert(binary()) :: any()
  def from_binary_with_convert(binary) do
    from_binary(binary)
    |> do_convert()
  end

  defp do_convert(entity) when is_list(entity) do
    for v <- entity, into: [], do: do_convert(v)
  end

  defp do_convert(%Regex{} = entity), do: inspect(entity)

  defp do_convert(entity) when is_map(entity) do
    for {k, v} <- entity, into: %{}, do: {do_convert(k), do_convert(v)}
  end

  defp do_convert({:dispatch, [entity]}), do: %{"tuple" => [":dispatch", [inspect(entity)]]}
  defp do_convert({:partial_chain, entity}), do: %{"tuple" => [":partial_chain", inspect(entity)]}

  defp do_convert(entity) when is_tuple(entity),
    do: %{"tuple" => do_convert(Tuple.to_list(entity))}

  defp do_convert(entity) when is_boolean(entity) or is_number(entity) or is_nil(entity),
    do: entity

  defp do_convert(entity) when is_atom(entity) do
    string = to_string(entity)

    if String.starts_with?(string, "Elixir."),
      do: do_convert(string),
      else: ":" <> string
  end

  defp do_convert("Elixir." <> module_name), do: module_name

  defp do_convert(entity) when is_binary(entity), do: entity

  @spec transform(any()) :: binary()
  def transform(entity) when is_binary(entity) or is_map(entity) or is_list(entity) do
    :erlang.term_to_binary(do_transform(entity))
  end

  def transform(entity), do: :erlang.term_to_binary(entity)

  defp do_transform(%Regex{} = entity), do: entity

  defp do_transform(%{"tuple" => [":dispatch", [entity]]}) do
    {dispatch_settings, []} = do_eval(entity)
    {:dispatch, [dispatch_settings]}
  end

  defp do_transform(%{"tuple" => [":partial_chain", entity]}) do
    {partial_chain, []} = do_eval(entity)
    {:partial_chain, partial_chain}
  end

  defp do_transform(%{"tuple" => entity}) do
    Enum.reduce(entity, {}, fn val, acc -> Tuple.append(acc, do_transform(val)) end)
  end

  defp do_transform(entity) when is_map(entity) do
    for {k, v} <- entity, into: %{}, do: {do_transform(k), do_transform(v)}
  end

  defp do_transform(entity) when is_list(entity) do
    for v <- entity, into: [], do: do_transform(v)
  end

  defp do_transform(entity) when is_binary(entity) do
    String.trim(entity)
    |> do_transform_string()
  end

  defp do_transform(entity), do: entity

  defp do_transform_string("~r/" <> pattern) do
    modificator = String.split(pattern, "/") |> List.last()
    pattern = String.trim_trailing(pattern, "/" <> modificator)

    case modificator do
      "" -> ~r/#{pattern}/
      "i" -> ~r/#{pattern}/i
      "u" -> ~r/#{pattern}/u
      "s" -> ~r/#{pattern}/s
    end
  end

  defp do_transform_string(":" <> atom), do: String.to_atom(atom)

  defp do_transform_string(value) do
    if String.starts_with?(value, "Pleroma") or String.starts_with?(value, "Phoenix"),
      do: String.to_existing_atom("Elixir." <> value),
      else: value
  end

  defp do_eval(entity) do
    cleaned_string = String.replace(entity, ~r/[^\w|^{:,[|^,|^[|^\]^}|^\/|^\.|^"]^\s/, "")
    Code.eval_string(cleaned_string, [], requires: [], macros: [])
  end
end
