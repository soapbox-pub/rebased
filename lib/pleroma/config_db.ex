# Pleroma: A lightweight social networking server
# Copyright © 2017-2022 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.ConfigDB do
  use Ecto.Schema

  import Ecto.Changeset
  import Ecto.Query, only: [select: 3, from: 2]
  import Pleroma.Web.Gettext

  alias __MODULE__
  alias Pleroma.Repo

  @type t :: %__MODULE__{}

  @full_subkey_update [
    {:pleroma, :assets, :mascots},
    {:pleroma, :emoji, :groups},
    {:pleroma, :workers, :retries},
    {:pleroma, :mrf_subchain, :match_actor},
    {:pleroma, :mrf_keyword, :replace}
  ]

  schema "config" do
    field(:key, Pleroma.EctoType.Config.Atom)
    field(:group, Pleroma.EctoType.Config.Atom)
    field(:value, Pleroma.EctoType.Config.BinaryValue)
    field(:db, {:array, :string}, virtual: true, default: [])

    timestamps()
  end

  @spec get_all_as_keyword() :: keyword()
  def get_all_as_keyword do
    ConfigDB
    |> select([c], {c.group, c.key, c.value})
    |> Repo.all()
    |> Enum.reduce([], fn {group, key, value}, acc ->
      Keyword.update(acc, group, [{key, value}], &Keyword.merge(&1, [{key, value}]))
    end)
  end

  @spec get_all_by_group(atom() | String.t()) :: [t()]
  def get_all_by_group(group) do
    from(c in ConfigDB, where: c.group == ^group) |> Repo.all()
  end

  @spec get_by_group_and_key(atom() | String.t(), atom() | String.t()) :: t() | nil
  def get_by_group_and_key(group, key) do
    get_by_params(%{group: group, key: key})
  end

  @spec get_by_params(map()) :: ConfigDB.t() | nil
  def get_by_params(%{group: _, key: _} = params), do: Repo.get_by(ConfigDB, params)

  @spec changeset(ConfigDB.t(), map()) :: Changeset.t()
  def changeset(config, params \\ %{}) do
    config
    |> cast(params, [:key, :group, :value])
    |> validate_required([:key, :group, :value])
    |> unique_constraint(:key, name: :config_group_key_index)
  end

  defp create(params) do
    %ConfigDB{}
    |> changeset(params)
    |> Repo.insert()
  end

  defp update(%ConfigDB{} = config, %{value: value}) do
    config
    |> changeset(%{value: value})
    |> Repo.update()
  end

  @spec get_db_keys(keyword(), any()) :: [String.t()]
  def get_db_keys(value, key) do
    keys =
      if Keyword.keyword?(value) do
        Keyword.keys(value)
      else
        [key]
      end

    Enum.map(keys, &to_json_types(&1))
  end

  @spec merge_group(atom(), atom(), keyword(), keyword()) :: keyword()
  def merge_group(group, key, old_value, new_value) do
    new_keys = to_mapset(new_value)

    intersect_keys = old_value |> to_mapset() |> MapSet.intersection(new_keys) |> MapSet.to_list()

    merged_value = ConfigDB.merge(old_value, new_value)

    @full_subkey_update
    |> Enum.map(fn
      {g, k, subkey} when g == group and k == key ->
        if subkey in intersect_keys, do: subkey, else: []

      _ ->
        []
    end)
    |> List.flatten()
    |> Enum.reduce(merged_value, &Keyword.put(&2, &1, new_value[&1]))
  end

  defp to_mapset(keyword) do
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
    params = Map.put(params, :value, to_elixir_types(params[:value]))
    search_opts = Map.take(params, [:group, :key])

    with %ConfigDB{} = config <- ConfigDB.get_by_params(search_opts),
         {_, true, config} <- {:partial_update, can_be_partially_updated?(config), config},
         {_, true, config} <-
           {:can_be_merged, is_list(params[:value]) and is_list(config.value), config} do
      new_value = merge_group(config.group, config.key, config.value, params[:value])
      update(config, %{value: new_value})
    else
      {reason, false, config} when reason in [:partial_update, :can_be_merged] ->
        update(config, params)

      nil ->
        create(params)
    end
  end

  defp can_be_partially_updated?(%ConfigDB{} = config), do: not only_full_update?(config)

  defp only_full_update?(%ConfigDB{group: group, key: key}) do
    full_key_update = [
      {:pleroma, :ecto_repos},
      {:quack, :meta},
      {:mime, :types},
      {:cors_plug, [:max_age, :methods, :expose, :headers]},
      {:swarm, :node_blacklist},
      {:logger, :backends}
    ]

    Enum.any?(full_key_update, fn
      {s_group, s_key} ->
        group == s_group and ((is_list(s_key) and key in s_key) or key == s_key)
    end)
  end

  @spec delete(ConfigDB.t() | map()) :: {:ok, ConfigDB.t()} | {:error, Changeset.t()}
  def delete(%ConfigDB{} = config), do: Repo.delete(config)

  def delete(params) do
    search_opts = Map.delete(params, :subkeys)

    with %ConfigDB{} = config <- ConfigDB.get_by_params(search_opts),
         {config, sub_keys} when is_list(sub_keys) <- {config, params[:subkeys]},
         keys <- Enum.map(sub_keys, &string_to_elixir_types(&1)),
         {_, config, new_value} when new_value != [] <-
           {:partial_remove, config, Keyword.drop(config.value, keys)} do
      update(config, %{value: new_value})
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

  @spec to_json_types(term()) :: map() | list() | boolean() | String.t()
  def to_json_types(entity) when is_list(entity) do
    Enum.map(entity, &to_json_types/1)
  end

  def to_json_types(%Regex{} = entity), do: inspect(entity)

  def to_json_types(entity) when is_map(entity) do
    Map.new(entity, fn {k, v} -> {to_json_types(k), to_json_types(v)} end)
  end

  def to_json_types({:args, args}) when is_list(args) do
    arguments =
      Enum.map(args, fn
        arg when is_tuple(arg) -> inspect(arg)
        arg -> to_json_types(arg)
      end)

    %{"tuple" => [":args", arguments]}
  end

  def to_json_types({:proxy_url, {type, :localhost, port}}) do
    %{"tuple" => [":proxy_url", %{"tuple" => [to_json_types(type), "localhost", port]}]}
  end

  def to_json_types({:proxy_url, {type, host, port}}) when is_tuple(host) do
    ip =
      host
      |> :inet_parse.ntoa()
      |> to_string()

    %{
      "tuple" => [
        ":proxy_url",
        %{"tuple" => [to_json_types(type), ip, port]}
      ]
    }
  end

  def to_json_types({:proxy_url, {type, host, port}}) do
    %{
      "tuple" => [
        ":proxy_url",
        %{"tuple" => [to_json_types(type), to_string(host), port]}
      ]
    }
  end

  def to_json_types({:partial_chain, entity}),
    do: %{"tuple" => [":partial_chain", inspect(entity)]}

  def to_json_types(entity) when is_tuple(entity) do
    value =
      entity
      |> Tuple.to_list()
      |> to_json_types()

    %{"tuple" => value}
  end

  def to_json_types(entity) when is_binary(entity), do: entity

  def to_json_types(entity) when is_boolean(entity) or is_number(entity) or is_nil(entity) do
    entity
  end

  def to_json_types(entity) when entity in [:"tlsv1.1", :"tlsv1.2", :"tlsv1.3"] do
    ":#{entity}"
  end

  def to_json_types(entity) when is_atom(entity), do: inspect(entity)

  @spec to_elixir_types(boolean() | String.t() | map() | list()) :: term()
  def to_elixir_types(%{"tuple" => [":args", args]}) when is_list(args) do
    arguments =
      Enum.map(args, fn arg ->
        if String.contains?(arg, ["{", "}"]) do
          {elem, []} = Code.eval_string(arg)
          elem
        else
          to_elixir_types(arg)
        end
      end)

    {:args, arguments}
  end

  def to_elixir_types(%{"tuple" => [":proxy_url", %{"tuple" => [type, host, port]}]}) do
    {:proxy_url, {string_to_elixir_types(type), parse_host(host), port}}
  end

  def to_elixir_types(%{"tuple" => [":partial_chain", entity]}) do
    {partial_chain, []} =
      entity
      |> String.replace(~r/[^\w|^{:,[|^,|^[|^\]^}|^\/|^\.|^"]^\s/, "")
      |> Code.eval_string()

    {:partial_chain, partial_chain}
  end

  def to_elixir_types(%{"tuple" => entity}) do
    Enum.reduce(entity, {}, &Tuple.append(&2, to_elixir_types(&1)))
  end

  def to_elixir_types(entity) when is_map(entity) do
    Map.new(entity, fn {k, v} -> {to_elixir_types(k), to_elixir_types(v)} end)
  end

  def to_elixir_types(entity) when is_list(entity) do
    Enum.map(entity, &to_elixir_types/1)
  end

  def to_elixir_types(entity) when is_binary(entity) do
    entity
    |> String.trim()
    |> string_to_elixir_types()
  end

  def to_elixir_types(entity), do: entity

  @spec string_to_elixir_types(String.t()) ::
          atom() | Regex.t() | module() | String.t() | no_return()
  def string_to_elixir_types("~r" <> _pattern = regex) do
    pattern =
      ~r/^~r(?'delimiter'[\/|"'([{<]{1})(?'pattern'.+)[\/|"')\]}>]{1}(?'modifier'[uismxfU]*)/u

    delimiters = ["/", "|", "\"", "'", {"(", ")"}, {"[", "]"}, {"{", "}"}, {"<", ">"}]

    with %{"modifier" => modifier, "pattern" => pattern, "delimiter" => regex_delimiter} <-
           Regex.named_captures(pattern, regex),
         {:ok, {leading, closing}} <- find_valid_delimiter(delimiters, pattern, regex_delimiter),
         {result, _} <- Code.eval_string("~r#{leading}#{pattern}#{closing}#{modifier}") do
      result
    end
  end

  def string_to_elixir_types(":" <> atom), do: String.to_atom(atom)

  def string_to_elixir_types(value) do
    if module_name?(value) do
      String.to_existing_atom("Elixir." <> value)
    else
      value
    end
  end

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

  @spec module_name?(String.t()) :: boolean()
  def module_name?(string) do
    Regex.match?(~r/^(Pleroma|Phoenix|Tesla|Quack|Ueberauth|Swoosh)\./, string) or
      string in ["Oban", "Ueberauth", "ExSyslogger", "ConcurrentLimiter"]
  end
end
