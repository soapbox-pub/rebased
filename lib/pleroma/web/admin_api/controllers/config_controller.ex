# Pleroma: A lightweight social networking server
# Copyright © 2017-2022 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.AdminAPI.ConfigController do
  use Pleroma.Web, :controller

  alias Pleroma.Config
  alias Pleroma.ConfigDB
  alias Pleroma.Web.Plugs.OAuthScopesPlug

  plug(Pleroma.Web.ApiSpec.CastAndValidate)
  plug(OAuthScopesPlug, %{scopes: ["admin:write"]} when action == :update)

  plug(
    OAuthScopesPlug,
    %{scopes: ["admin:read"]}
    when action in [:show, :descriptions]
  )

  action_fallback(Pleroma.Web.AdminAPI.FallbackController)

  defdelegate open_api_operation(action), to: Pleroma.Web.ApiSpec.Admin.ConfigOperation

  def descriptions(conn, _params) do
    descriptions = Enum.filter(Pleroma.Docs.JSON.compiled_descriptions(), &whitelisted_config?/1)

    json(conn, descriptions)
  end

  def show(conn, %{only_db: true}) do
    with :ok <- configurable_from_database() do
      configs = Pleroma.Repo.all(ConfigDB)

      render(conn, "index.json", %{
        configs: configs,
        need_reboot: Restarter.Pleroma.need_reboot?()
      })
    end
  end

  def show(conn, _params) do
    with :ok <- configurable_from_database() do
      configs = ConfigDB.get_all_as_keyword()

      merged =
        Config.Holder.default_config()
        |> ConfigDB.merge(configs)
        |> Enum.map(fn {group, values} ->
          Enum.map(values, fn {key, value} ->
            db =
              if configs[group][key] do
                ConfigDB.get_db_keys(configs[group][key], key)
              end

            db_value = configs[group][key]

            merged_value =
              if not is_nil(db_value) and Keyword.keyword?(db_value) and
                   ConfigDB.sub_key_full_update?(group, key, Keyword.keys(db_value)) do
                ConfigDB.merge_group(group, key, value, db_value)
              else
                value
              end

            %ConfigDB{
              group: group,
              key: key,
              value: merged_value
            }
            |> Pleroma.Maps.put_if_present(:db, db)
          end)
        end)
        |> List.flatten()

      render(conn, "index.json", %{
        configs: merged,
        need_reboot: Restarter.Pleroma.need_reboot?()
      })
    end
  end

  def update(%{body_params: %{configs: configs}} = conn, _) do
    with :ok <- configurable_from_database() do
      results =
        configs
        |> Enum.filter(&whitelisted_config?/1)
        |> Enum.map(fn
          %{group: group, key: key, delete: true} = params ->
            ConfigDB.delete(%{group: group, key: key, subkeys: params[:subkeys]})

          %{group: group, key: key, value: value} ->
            ConfigDB.update_or_create(%{group: group, key: key, value: value})
        end)
        |> Enum.reject(fn {result, _} -> result == :error end)

      {deleted, updated} =
        results
        |> Enum.map(fn {:ok, %{key: key, value: value} = config} ->
          Map.put(config, :db, ConfigDB.get_db_keys(value, key))
        end)
        |> Enum.split_with(&(Ecto.get_meta(&1, :state) == :deleted))

      Config.TransferTask.load_and_update_env(deleted, false)

      if not Restarter.Pleroma.need_reboot?() do
        changed_reboot_settings? =
          (updated ++ deleted)
          |> Enum.any?(&Config.TransferTask.pleroma_need_restart?(&1.group, &1.key, &1.value))

        if changed_reboot_settings?, do: Restarter.Pleroma.need_reboot()
      end

      render(conn, "index.json", %{
        configs: updated,
        need_reboot: Restarter.Pleroma.need_reboot?()
      })
    end
  end

  defp configurable_from_database do
    if Config.get(:configurable_from_database) do
      :ok
    else
      {:error, "You must enable configurable_from_database in your config file."}
    end
  end

  defp whitelisted_config?(group, key) do
    if whitelisted_configs = Config.get(:database_config_whitelist) do
      Enum.any?(whitelisted_configs, fn
        {whitelisted_group} ->
          group == inspect(whitelisted_group)

        {whitelisted_group, whitelisted_key} ->
          group == inspect(whitelisted_group) && key == inspect(whitelisted_key)
      end)
    else
      true
    end
  end

  defp whitelisted_config?(%{group: group, key: key}) do
    whitelisted_config?(group, key)
  end

  defp whitelisted_config?(%{group: group} = config) do
    whitelisted_config?(group, config[:key])
  end
end
