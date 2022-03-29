# Pleroma: A lightweight social networking server
# Copyright © 2017-2022 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Config.TransferTask do
  use Task

  alias Pleroma.Config
  alias Pleroma.ConfigDB
  alias Pleroma.Repo

  require Logger

  @type env() :: :test | :benchmark | :dev | :prod

  defp reboot_time_keys,
    do: [
      {:pleroma, :hackney_pools},
      {:pleroma, :shout},
      {:pleroma, Oban},
      {:pleroma, :rate_limit},
      {:pleroma, :markup},
      {:pleroma, :streamer},
      {:pleroma, :pools},
      {:pleroma, :connections_pool}
    ]

  defp reboot_time_subkeys,
    do: [
      {:pleroma, Pleroma.Captcha, [:seconds_valid]},
      {:pleroma, Pleroma.Upload, [:proxy_remote]},
      {:pleroma, :instance, [:upload_limit]},
      {:pleroma, :gopher, [:enabled]}
    ]

  def start_link(restart_pleroma? \\ true) do
    load_and_update_env([], restart_pleroma?)
    if Config.get(:env) == :test, do: Ecto.Adapters.SQL.Sandbox.checkin(Repo)
    :ignore
  end

  @spec load_and_update_env([ConfigDB.t()], boolean()) :: :ok
  def load_and_update_env(deleted_settings \\ [], restart_pleroma? \\ true) do
    with {_, true} <- {:configurable, Config.get(:configurable_from_database)} do
      # We need to restart applications for loaded settings take effect

      {logger, other} =
        (Repo.all(ConfigDB) ++ deleted_settings)
        |> Enum.map(&merge_with_default/1)
        |> Enum.split_with(fn {group, _, _, _} -> group in [:logger, :quack] end)

      logger
      |> Enum.sort()
      |> Enum.each(&configure/1)

      started_applications = Application.started_applications()

      # TODO: some problem with prometheus after restart!
      reject = [nil, :prometheus, :postgrex]

      reject =
        if restart_pleroma? do
          reject
        else
          [:pleroma | reject]
        end

      other
      |> Enum.map(&update/1)
      |> Enum.uniq()
      |> Enum.reject(&(&1 in reject))
      |> maybe_set_pleroma_last()
      |> Enum.each(&restart(started_applications, &1, Config.get(:env)))

      :ok
    else
      {:configurable, false} -> Restarter.Pleroma.rebooted()
    end
  end

  defp maybe_set_pleroma_last(apps) do
    # to be ensured that pleroma will be restarted last
    if :pleroma in apps do
      apps
      |> List.delete(:pleroma)
      |> List.insert_at(-1, :pleroma)
    else
      Restarter.Pleroma.rebooted()
      apps
    end
  end

  defp merge_with_default(%{group: group, key: key, value: value} = setting) do
    default = Config.Holder.default_config(group, key)

    merged =
      cond do
        Ecto.get_meta(setting, :state) == :deleted -> default
        can_be_merged?(default, value) -> ConfigDB.merge_group(group, key, default, value)
        true -> value
      end

    {group, key, value, merged}
  end

  # change logger configuration in runtime, without restart
  defp configure({:quack, key, _, merged}) do
    Logger.configure_backend(Quack.Logger, [{key, merged}])
    :ok = update_env(:quack, key, merged)
  end

  defp configure({_, :backends, _, merged}) do
    # removing current backends
    Enum.each(Application.get_env(:logger, :backends), &Logger.remove_backend/1)

    Enum.each(merged, &Logger.add_backend/1)

    :ok = update_env(:logger, :backends, merged)
  end

  defp configure({_, key, _, merged}) when key in [:console, :ex_syslogger] do
    merged =
      if key == :console do
        put_in(merged[:format], merged[:format] <> "\n")
      else
        merged
      end

    backend =
      if key == :ex_syslogger,
        do: {ExSyslogger, :ex_syslogger},
        else: key

    Logger.configure_backend(backend, merged)
    :ok = update_env(:logger, key, merged)
  end

  defp configure({_, key, _, merged}) do
    Logger.configure([{key, merged}])
    :ok = update_env(:logger, key, merged)
  end

  defp update({group, key, value, merged}) do
    try do
      :ok = update_env(group, key, merged)

      if group != :pleroma or pleroma_need_restart?(group, key, value), do: group
    rescue
      error ->
        error_msg =
          "updating env causes error, group: #{inspect(group)}, key: #{inspect(key)}, value: #{inspect(value)} error: #{inspect(error)}"

        Logger.warn(error_msg)

        nil
    end
  end

  defp update_env(group, key, nil), do: Application.delete_env(group, key)
  defp update_env(group, key, value), do: Application.put_env(group, key, value)

  @spec pleroma_need_restart?(atom(), atom(), any()) :: boolean()
  def pleroma_need_restart?(group, key, value) do
    group_and_key_need_reboot?(group, key) or group_and_subkey_need_reboot?(group, key, value)
  end

  defp group_and_key_need_reboot?(group, key) do
    Enum.any?(reboot_time_keys(), fn {g, k} -> g == group and k == key end)
  end

  defp group_and_subkey_need_reboot?(group, key, value) do
    Keyword.keyword?(value) and
      Enum.any?(reboot_time_subkeys(), fn {g, k, subkeys} ->
        g == group and k == key and
          Enum.any?(Keyword.keys(value), &(&1 in subkeys))
      end)
  end

  defp restart(_, :pleroma, env), do: Restarter.Pleroma.restart_after_boot(env)

  defp restart(started_applications, app, _) do
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
