# Pleroma: A lightweight social networking server
# Copyright © 2017-2020 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Config.DeprecationWarnings do
  alias Pleroma.Config

  require Logger
  alias Pleroma.Config

  @type config_namespace() :: atom() | [atom()]
  @type config_map() :: {config_namespace(), config_namespace(), String.t()}

  @mrf_config_map [
    {[:instance, :rewrite_policy], [:mrf, :policies],
     "\n* `config :pleroma, :instance, rewrite_policy` is now `config :pleroma, :mrf, policies`"},
    {[:instance, :mrf_transparency], [:mrf, :transparency],
     "\n* `config :pleroma, :instance, mrf_transparency` is now `config :pleroma, :mrf, transparency`"},
    {[:instance, :mrf_transparency_exclusions], [:mrf, :transparency_exclusions],
     "\n* `config :pleroma, :instance, mrf_transparency_exclusions` is now `config :pleroma, :mrf, transparency_exclusions`"}
  ]

  def check_hellthread_threshold do
    if Config.get([:mrf_hellthread, :threshold]) do
      Logger.warn("""
      !!!DEPRECATION WARNING!!!
      You are using the old configuration mechanism for the hellthread filter. Please check config.md.
      """)

      :error
    else
      :ok
    end
  end

  def warn do
    with :ok <- check_hellthread_threshold(),
         :ok <- check_old_mrf_config(),
         :ok <- check_media_proxy_whitelist_config(),
         :ok <- check_welcome_message_config(),
         :ok <- check_gun_pool_options(),
         :ok <- check_activity_expiration_config(),
         :ok <- check_remote_ip_plug_name() do
      :ok
    else
      _ ->
        :error
    end
  end

  def check_welcome_message_config do
    instance_config = Pleroma.Config.get([:instance])

    use_old_config =
      Keyword.has_key?(instance_config, :welcome_user_nickname) or
        Keyword.has_key?(instance_config, :welcome_message)

    if use_old_config do
      Logger.error("""
      !!!DEPRECATION WARNING!!!
      Your config is using the old namespace for Welcome messages configuration. You need to convert to the new namespace. e.g.,
      \n* `config :pleroma, :instance, welcome_user_nickname` and `config :pleroma, :instance, welcome_message` are now equal to:
      \n* `config :pleroma, :welcome, direct_message: [enabled: true, sender_nickname: "NICKNAME", message: "Your welcome message"]`"
      """)

      :error
    else
      :ok
    end
  end

  def check_old_mrf_config do
    warning_preface = """
    !!!DEPRECATION WARNING!!!
    Your config is using old namespaces for MRF configuration. They should work for now, but you are advised to change to new namespaces to prevent possible issues later:
    """

    move_namespace_and_warn(@mrf_config_map, warning_preface)
  end

  @spec move_namespace_and_warn([config_map()], String.t()) :: :ok | nil
  def move_namespace_and_warn(config_map, warning_preface) do
    warning =
      Enum.reduce(config_map, "", fn
        {old, new, err_msg}, acc ->
          old_config = Config.get(old)

          if old_config do
            Config.put(new, old_config)
            acc <> err_msg
          else
            acc
          end
      end)

    if warning == "" do
      :ok
    else
      Logger.warn(warning_preface <> warning)
      :error
    end
  end

  @spec check_media_proxy_whitelist_config() :: :ok | nil
  def check_media_proxy_whitelist_config do
    whitelist = Config.get([:media_proxy, :whitelist])

    if Enum.any?(whitelist, &(not String.starts_with?(&1, "http"))) do
      Logger.warn("""
      !!!DEPRECATION WARNING!!!
      Your config is using old format (only domain) for MediaProxy whitelist option. Setting should work for now, but you are advised to change format to scheme with port to prevent possible issues later.
      """)

      :error
    else
      :ok
    end
  end

  def check_gun_pool_options do
    pool_config = Config.get(:connections_pool)

    if timeout = pool_config[:await_up_timeout] do
      Logger.warn("""
      !!!DEPRECATION WARNING!!!
      Your config is using old setting `config :pleroma, :connections_pool, await_up_timeout`. Please change to `config :pleroma, :connections_pool, connect_timeout` to ensure compatibility with future releases.
      """)

      Config.put(:connections_pool, Keyword.put_new(pool_config, :connect_timeout, timeout))
    end

    pools_configs = Config.get(:pools)

    warning_preface = """
    !!!DEPRECATION WARNING!!!
    Your config is using old setting name `timeout` instead of `recv_timeout` in pool settings. Setting should work for now, but you are advised to change format to scheme with port to prevent possible issues later.
    """

    updated_config =
      Enum.reduce(pools_configs, [], fn {pool_name, config}, acc ->
        if timeout = config[:timeout] do
          Keyword.put(acc, pool_name, Keyword.put_new(config, :recv_timeout, timeout))
        else
          acc
        end
      end)

    if updated_config != [] do
      pool_warnings =
        updated_config
        |> Keyword.keys()
        |> Enum.map(fn pool_name ->
          "\n* `:timeout` options in #{pool_name} pool is now `:recv_timeout`"
        end)

      Logger.warn(Enum.join([warning_preface | pool_warnings]))

      Config.put(:pools, updated_config)
      :error
    else
      :ok
    end
  end

  @spec check_activity_expiration_config() :: :ok | nil
  def check_activity_expiration_config do
    warning_preface = """
    !!!DEPRECATION WARNING!!!
      Your config is using old namespace for activity expiration configuration. Setting should work for now, but you are advised to change to new namespace to prevent possible issues later:
    """

    move_namespace_and_warn(
      [
        {Pleroma.ActivityExpiration, Pleroma.Workers.PurgeExpiredActivity,
         "\n* `config :pleroma, Pleroma.ActivityExpiration` is now `config :pleroma, Pleroma.Workers.PurgeExpiredActivity`"}
      ],
      warning_preface
    )
  end

  @spec check_remote_ip_plug_name() :: :ok | nil
  def check_remote_ip_plug_name do
    warning_preface = """
    !!!DEPRECATION WARNING!!!
    Your config is using old namespace for RemoteIp Plug. Setting should work for now, but you are advised to change to new namespace to prevent possible issues later:
    """

    move_namespace_and_warn(
      [
        {Pleroma.Plugs.RemoteIp, Pleroma.Web.Plugs.RemoteIp,
         "\n* `config :pleroma, Pleroma.Plugs.RemoteIp` is now `config :pleroma, Pleroma.Web.Plugs.RemoteIp`"}
      ],
      warning_preface
    )
  end
end
