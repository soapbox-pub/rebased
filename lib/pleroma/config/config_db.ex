# Pleroma: A lightweight social networking server
# Copyright © 2017-2019 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.ConfigDB do
  use Ecto.Schema

  import Ecto.Changeset
  import Ecto.Query
  import Pleroma.Web.Gettext

  alias __MODULE__
  alias Pleroma.Repo

  @type t :: %__MODULE__{}

  @full_key_update [
    {:pleroma, :ecto_repos},
    {:quack, :meta},
    {:mime, :types},
    {:cors_plug, [:max_age, :methods, :expose, :headers]},
    {:auto_linker, :opts},
    {:swarm, :node_blacklist},
    {:logger, :backends}
  ]

  @full_subkey_update [
    {:pleroma, :assets, :mascots},
    {:pleroma, :emoji, :groups},
    {:pleroma, :workers, :retries},
    {:pleroma, :mrf_subchain, :match_actor},
    {:pleroma, :mrf_keyword, :replace}
  ]

  @regex ~r/^~r(?'delimiter'[\/|"'([{<]{1})(?'pattern'.+)[\/|"')\]}>]{1}(?'modifier'[uismxfU]*)/u

  @delimiters ["/", "|", "\"", "'", {"(", ")"}, {"[", "]"}, {"{", "}"}, {"<", ">"}]

  schema "config" do
    field(:key, :string)
    field(:group, :string)
    field(:value, :binary)
    field(:db, {:array, :string}, virtual: true, default: [])

    timestamps()
  end

  @spec get_all_as_keyword() :: keyword()
  def get_all_as_keyword do
    ConfigDB
    |> select([c], {c.group, c.key, c.value})
    |> Repo.all()
    |> Enum.reduce([], fn {group, key, value}, acc ->
      group = ConfigDB.from_string(group)
      key = ConfigDB.from_string(key)
      value = from_binary(value)

      Keyword.update(acc, group, [{key, value}], &Keyword.merge(&1, [{key, value}]))
    end)
  end

  @spec get_by_params(map()) :: ConfigDB.t() | nil
  def get_by_params(params), do: Repo.get_by(ConfigDB, params)

  @spec changeset(ConfigDB.t(), map()) :: Changeset.t()
  def changeset(config, params \\ %{}) do
    params = Map.put(params, :value, transform(params[:value]))

    config
    |> cast(params, [:key, :group, :value])
    |> validate_required([:key, :group, :value])
    |> unique_constraint(:key, name: :config_group_key_index)
  end

  @spec create(map()) :: {:ok, ConfigDB.t()} | {:error, Changeset.t()}
  def create(params) do
    %ConfigDB{}
    |> changeset(params)
    |> Repo.insert()
  end

  @spec update(ConfigDB.t(), map()) :: {:ok, ConfigDB.t()} | {:error, Changeset.t()}
  def update(%ConfigDB{} = config, %{value: value}) do
    config
    |> changeset(%{value: value})
    |> Repo.update()
  end

  @spec get_db_keys(ConfigDB.t()) :: [String.t()]
  def get_db_keys(%ConfigDB{} = config) do
    config.value
    |> ConfigDB.from_binary()
    |> get_db_keys(config.key)
  end

  @spec get_db_keys(keyword(), any()) :: [String.t()]
  def get_db_keys(value, key) do
    if Keyword.keyword?(value) do
      value |> Keyword.keys() |> Enum.map(&convert(&1))
    else
      [convert(key)]
    end
  end

  @spec merge_group(atom(), atom(), keyword(), keyword()) :: keyword()
  def merge_group(group, key, old_value, new_value) do
    new_keys = to_map_set(new_value)

    intersect_keys =
      old_value |> to_map_set() |> MapSet.intersection(new_keys) |> MapSet.to_list()

    merged_value = ConfigDB.merge(old_value, new_value)

    @full_subkey_update
    |> Enum.map(fn
      {g, k, subkey} when g == group and k == key ->
        if subkey in intersect_keys, do: subkey, else: []

      _ ->
        []
    end)
    |> List.flatten()
    |> Enum.reduce(merged_value, fn subkey, acc ->
      Keyword.put(acc, subkey, new_value[subkey])
    end)
  end

  defp to_map_set(keyword) do
    keyword
    |> Keyword.keys()
    |> MapSet.new()
  end

  @spec sub_key_full_update?(atom(), atom(), [Keyword.key()]) :: boolean()
  def sub_key_full_update?(group, key, subkeys) do
    Enum.any?(@full_subkey_update, fn {g, k, subkey} ->
      g == group and k == key and subkey in subkeys
    end)
  end

  @spec merge(keyword(), keyword()) :: keyword()
  def merge(config1, config2) when is_list(config1) and is_list(config2) do
    Keyword.merge(config1, config2, fn _, app1, app2 ->
      if Keyword.keyword?(app1) and Keyword.keyword?(app2) do
        Keyword.merge(app1, app2, &deep_merge/3)
      else
        app2
      end
    end)
  end

  defp deep_merge(_key, value1, value2) do
    if Keyword.keyword?(value1) and Keyword.keyword?(value2) do
      Keyword.merge(value1, value2, &deep_merge/3)
    else
      value2
    end
  end

  @spec update_or_create(map()) :: {:ok, ConfigDB.t()} | {:error, Changeset.t()}
  def update_or_create(params) do
    search_opts = Map.take(params, [:group, :key])

    with %ConfigDB{} = config <- ConfigDB.get_by_params(search_opts),
         {:partial_update, true, config} <-
           {:partial_update, can_be_partially_updated?(config), config},
         old_value <- from_binary(config.value),
         transformed_value <- do_transform(params[:value]),
         {:can_be_merged, true, config} <- {:can_be_merged, is_list(transformed_value), config},
         new_value <-
           merge_group(
             ConfigDB.from_string(config.group),
             ConfigDB.from_string(config.key),
             old_value,
             transformed_value
           ) do
      ConfigDB.update(config, %{value: new_value})
    else
      {reason, false, config} when reason in [:partial_update, :can_be_merged] ->
        ConfigDB.update(config, params)

      nil ->
        ConfigDB.create(params)
    end
  end

  defp can_be_partially_updated?(%ConfigDB{} = config), do: not only_full_update?(config)

  defp only_full_update?(%ConfigDB{} = config) do
    config_group = ConfigDB.from_string(config.group)
    config_key = ConfigDB.from_string(config.key)

    Enum.any?(@full_key_update, fn
      {group, key} when is_list(key) ->
        config_group == group and config_key in key

      {group, key} ->
        config_group == group and config_key == key
    end)
  end

  @spec delete(map()) :: {:ok, ConfigDB.t()} | {:error, Changeset.t()}
  def delete(params) do
    search_opts = Map.delete(params, :subkeys)

    with %ConfigDB{} = config <- ConfigDB.get_by_params(search_opts),
         {config, sub_keys} when is_list(sub_keys) <- {config, params[:subkeys]},
         old_value <- from_binary(config.value),
         keys <- Enum.map(sub_keys, &do_transform_string(&1)),
         {:partial_remove, config, new_value} when new_value != [] <-
           {:partial_remove, config, Keyword.drop(old_value, keys)} do
      ConfigDB.update(config, %{value: new_value})
    else
      {:partial_remove, config, []} ->
        Repo.delete(config)

      {config, nil} ->
        Repo.delete(config)

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
    binary
    |> from_binary()
    |> do_convert()
  end

  @spec from_string(String.t()) :: atom() | no_return()
  def from_string(":" <> entity), do: String.to_existing_atom(entity)

  def from_string(entity) when is_binary(entity) do
    if is_module_name?(entity) do
      String.to_existing_atom("Elixir.#{entity}")
    else
      entity
    end
  end

  @spec convert(any()) :: any()
  def convert(entity), do: do_convert(entity)

  defp do_convert(entity) when is_list(entity) do
    for v <- entity, into: [], do: do_convert(v)
  end

  defp do_convert(%Regex{} = entity), do: inspect(entity)

  defp do_convert(entity) when is_map(entity) do
    for {k, v} <- entity, into: %{}, do: {do_convert(k), do_convert(v)}
  end

  defp do_convert({:proxy_url, {type, :localhost, port}}) do
    %{"tuple" => [":proxy_url", %{"tuple" => [do_convert(type), "localhost", port]}]}
  end

  defp do_convert({:proxy_url, {type, host, port}}) when is_tuple(host) do
    ip =
      host
      |> :inet_parse.ntoa()
      |> to_string()

    %{
      "tuple" => [
        ":proxy_url",
        %{"tuple" => [do_convert(type), ip, port]}
      ]
    }
  end

  defp do_convert({:proxy_url, {type, host, port}}) do
    %{
      "tuple" => [
        ":proxy_url",
        %{"tuple" => [do_convert(type), to_string(host), port]}
      ]
    }
  end

  defp do_convert({:partial_chain, entity}), do: %{"tuple" => [":partial_chain", inspect(entity)]}

  defp do_convert(entity) when is_tuple(entity) do
    value =
      entity
      |> Tuple.to_list()
      |> do_convert()

    %{"tuple" => value}
  end

  defp do_convert(entity) when is_boolean(entity) or is_number(entity) or is_nil(entity) do
    entity
  end

  defp do_convert(entity)
       when is_atom(entity) and entity in [:"tlsv1.1", :"tlsv1.2", :"tlsv1.3"] do
    ":#{entity}"
  end

  defp do_convert(entity) when is_atom(entity), do: inspect(entity)

  defp do_convert(entity) when is_binary(entity), do: entity

  @spec transform(any()) :: binary() | no_return()
  def transform(entity) when is_binary(entity) or is_map(entity) or is_list(entity) do
    entity
    |> do_transform()
    |> to_binary()
  end

  def transform(entity), do: to_binary(entity)

  @spec transform_with_out_binary(any()) :: any()
  def transform_with_out_binary(entity), do: do_transform(entity)

  @spec to_binary(any()) :: binary()
  def to_binary(entity), do: :erlang.term_to_binary(entity)

  defp do_transform(%Regex{} = entity), do: entity

  defp do_transform(%{"tuple" => [":proxy_url", %{"tuple" => [type, host, port]}]}) do
    {:proxy_url, {do_transform_string(type), parse_host(host), port}}
  end

  defp do_transform(%{"tuple" => [":partial_chain", entity]}) do
    {partial_chain, []} =
      entity
      |> String.replace(~r/[^\w|^{:,[|^,|^[|^\]^}|^\/|^\.|^"]^\s/, "")
      |> Code.eval_string()

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
    entity
    |> String.trim()
    |> do_transform_string()
  end

  defp do_transform(entity), do: entity

  defp parse_host("localhost"), do: :localhost

  defp parse_host(host) do
    charlist = to_charlist(host)

    case :inet.parse_address(charlist) do
      {:error, :einval} ->
        charlist

      {:ok, ip} ->
        ip
    end
  end

  defp find_valid_delimiter([], _string, _) do
    raise(ArgumentError, message: "valid delimiter for Regex expression not found")
  end

  defp find_valid_delimiter([{leading, closing} = delimiter | others], pattern, regex_delimiter)
       when is_tuple(delimiter) do
    if String.contains?(pattern, closing) do
      find_valid_delimiter(others, pattern, regex_delimiter)
    else
      {:ok, {leading, closing}}
    end
  end

  defp find_valid_delimiter([delimiter | others], pattern, regex_delimiter) do
    if String.contains?(pattern, delimiter) do
      find_valid_delimiter(others, pattern, regex_delimiter)
    else
      {:ok, {delimiter, delimiter}}
    end
  end

  defp do_transform_string("~r" <> _pattern = regex) do
    with %{"modifier" => modifier, "pattern" => pattern, "delimiter" => regex_delimiter} <-
           Regex.named_captures(@regex, regex),
         {:ok, {leading, closing}} <- find_valid_delimiter(@delimiters, pattern, regex_delimiter),
         {result, _} <- Code.eval_string("~r#{leading}#{pattern}#{closing}#{modifier}") do
      result
    end
  end

  defp do_transform_string(":" <> atom), do: String.to_atom(atom)

  defp do_transform_string(value) do
    if is_module_name?(value) do
      String.to_existing_atom("Elixir." <> value)
    else
      value
    end
  end

  @spec is_module_name?(String.t()) :: boolean()
  def is_module_name?(string) do
    Regex.match?(~r/^(Pleroma|Phoenix|Tesla|Quack|Ueberauth)\./, string) or
      string in ["Oban", "Ueberauth", "ExSyslogger"]
  end
end
