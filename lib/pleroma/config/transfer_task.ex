# Pleroma: A lightweight social networking server
# Copyright © 2017-2019 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Config.TransferTask do
  use Task

  alias Pleroma.ConfigDB
  alias Pleroma.Repo

  require Logger

  @type env() :: :test | :benchmark | :dev | :prod

  @reboot_time_keys [
    {:pleroma, :hackney_pools},
    {:pleroma, :chat},
    {:pleroma, Oban},
    {:pleroma, :rate_limit},
    {:pleroma, :markup},
    {:plerome, :streamer}
  ]

  @reboot_time_subkeys [
    {:pleroma, Pleroma.Captcha, [:seconds_valid]},
    {:pleroma, Pleroma.Upload, [:proxy_remote]},
    {:pleroma, :instance, [:upload_limit]},
    {:pleroma, :email_notifications, [:digest]},
    {:pleroma, :oauth2, [:clean_expired_tokens]},
    {:pleroma, Pleroma.ActivityExpiration, [:enabled]},
    {:pleroma, Pleroma.ScheduledActivity, [:enabled]},
    {:pleroma, :gopher, [:enabled]}
  ]

  @reject [nil, :prometheus]

  def start_link(_) do
    load_and_update_env()
    if Pleroma.Config.get(:env) == :test, do: Ecto.Adapters.SQL.Sandbox.checkin(Repo)
    :ignore
  end

  @spec load_and_update_env([ConfigDB.t()]) :: :ok | false
  def load_and_update_env(deleted \\ [], restart_pleroma? \\ true) do
    with true <- Pleroma.Config.get(:configurable_from_database),
         true <- Ecto.Adapters.SQL.table_exists?(Repo, "config"),
         started_applications <- Application.started_applications() do
      # We need to restart applications for loaded settings take effect

      in_db = Repo.all(ConfigDB)

      with_deleted = in_db ++ deleted

      reject_for_restart = if restart_pleroma?, do: @reject, else: [:pleroma | @reject]

      applications =
        with_deleted
        |> Enum.map(&merge_and_update(&1))
        |> Enum.uniq()
        # TODO: some problem with prometheus after restart!
        |> Enum.reject(&(&1 in reject_for_restart))

      # to be ensured that pleroma will be restarted last
      applications =
        if :pleroma in applications do
          List.delete(applications, :pleroma) ++ [:pleroma]
        else
          applications
        end

      Enum.each(applications, &restart(started_applications, &1, Pleroma.Config.get(:env)))

      :ok
    end
  end

  defp merge_and_update(setting) do
    try do
      key = ConfigDB.from_string(setting.key)
      group = ConfigDB.from_string(setting.group)

      default = Pleroma.Config.Holder.config(group, key)
      value = ConfigDB.from_binary(setting.value)

      merged_value =
        if Ecto.get_meta(setting, :state) == :deleted do
          default
        else
          if can_be_merged?(default, value) do
            ConfigDB.merge_group(group, key, default, value)
          else
            value
          end
        end

      :ok = update_env(group, key, merged_value)

      if group != :logger do
        if group != :pleroma or pleroma_need_restart?(group, key, value) do
          group
        end
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

  @spec pleroma_need_restart?(atom(), atom(), any()) :: boolean()
  def pleroma_need_restart?(group, key, value) do
    group_and_key_need_reboot?(group, key) or group_and_subkey_need_reboot?(group, key, value)
  end

  defp group_and_key_need_reboot?(group, key) do
    Enum.any?(@reboot_time_keys, fn {g, k} -> g == group and k == key end)
  end

  defp group_and_subkey_need_reboot?(group, key, value) do
    Keyword.keyword?(value) and
      Enum.any?(@reboot_time_subkeys, fn {g, k, subkeys} ->
        g == group and k == key and
          Enum.any?(Keyword.keys(value), &(&1 in subkeys))
      end)
  end

  defp update_env(group, key, nil), do: Application.delete_env(group, key)
  defp update_env(group, key, value), do: Application.put_env(group, key, value)

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
