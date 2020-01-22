# Pleroma: A lightweight social networking server
# Copyright © 2017-2019 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Config.TransferTask do
  use Task

  alias Pleroma.ConfigDB
  alias Pleroma.Repo

  require Logger

  def start_link(_) do
    load_and_update_env()
    if Pleroma.Config.get(:env) == :test, do: Ecto.Adapters.SQL.Sandbox.checkin(Repo)
    :ignore
  end

  @spec load_and_update_env([ConfigDB.t()]) :: :ok | false
  def load_and_update_env(deleted \\ []) do
    with true <- Pleroma.Config.get(:configurable_from_database),
         true <- Ecto.Adapters.SQL.table_exists?(Repo, "config"),
         started_applications <- Application.started_applications() do
      # We need to restart applications for loaded settings take effect
      in_db = Repo.all(ConfigDB)

      with_deleted = in_db ++ deleted

      with_deleted
      |> Enum.map(&merge_and_update(&1))
      |> Enum.uniq()
      # TODO: some problem with prometheus after restart!
      |> Enum.reject(&(&1 in [:pleroma, nil, :prometheus]))
      |> Enum.each(&restart(started_applications, &1))

      :ok
    end
  end

  defp merge_and_update(setting) do
    try do
      key = ConfigDB.from_string(setting.key)
      group = ConfigDB.from_string(setting.group)

      default = Pleroma.Config.Holder.config(group, key)
      merged_value = merge_value(setting, default, group, key)

      :ok = update_env(group, key, merged_value)

      if group != :logger do
        group
      else
        # change logger configuration in runtime, without restart
        if Keyword.keyword?(merged_value) and
             key not in [:compile_time_application, :backends, :compile_time_purge_matching] do
          Logger.configure_backend(key, merged_value)
        else
          Logger.configure([{key, merged_value}])
        end

        nil
      end
    rescue
      error ->
        error_msg =
          "updating env causes error, group: " <>
            inspect(setting.group) <>
            " key: " <>
            inspect(setting.key) <>
            " value: " <>
            inspect(ConfigDB.from_binary(setting.value)) <> " error: " <> inspect(error)

        Logger.warn(error_msg)

        nil
    end
  end

  defp merge_value(%{__meta__: %{state: :deleted}}, default, _group, _key), do: default

  defp merge_value(setting, default, group, key) do
    value = ConfigDB.from_binary(setting.value)

    if can_be_merged?(default, value) do
      ConfigDB.merge_group(group, key, default, value)
    else
      value
    end
  end

  defp update_env(group, key, nil), do: Application.delete_env(group, key)
  defp update_env(group, key, value), do: Application.put_env(group, key, value)

  defp restart(started_applications, app) do
    with {^app, _, _} <- List.keyfind(started_applications, app, 0),
         :ok <- Application.stop(app) do
      :ok = Application.start(app)
    else
      nil ->
        Logger.warn("#{app} is not started.")

      error ->
        error
        |> inspect()
        |> Logger.warn()
    end
  end

  defp can_be_merged?(val1, val2) when is_list(val1) and is_list(val2) do
    Keyword.keyword?(val1) and Keyword.keyword?(val2)
  end

  defp can_be_merged?(_val1, _val2), do: false
end
