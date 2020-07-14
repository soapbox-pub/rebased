# Pleroma: A lightweight social networking server
# Copyright © 2017-2020 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Config.DeprecationWarnings do
  alias Pleroma.Config

  require Logger
  alias Pleroma.Config

  @type config_namespace() :: [atom()]
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
    end
  end

  def mrf_user_allowlist do
    config = Config.get(:mrf_user_allowlist)

    if config && Enum.any?(config, fn {k, _} -> is_atom(k) end) do
      rewritten =
        Enum.reduce(Config.get(:mrf_user_allowlist), Map.new(), fn {k, v}, acc ->
          Map.put(acc, to_string(k), v)
        end)

      Config.put(:mrf_user_allowlist, rewritten)

      Logger.error("""
      !!!DEPRECATION WARNING!!!
      As of Pleroma 2.0.7, the `mrf_user_allowlist` setting changed of format.
      Pleroma 2.1 will remove support for the old format. Please change your configuration to match this:

      config :pleroma, :mrf_user_allowlist, #{inspect(rewritten, pretty: true)}
      """)
    end
  end

  def warn do
    check_hellthread_threshold()
    mrf_user_allowlist()
    check_old_mrf_config()
    check_media_proxy_whitelist_config()
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

    if warning != "" do
      Logger.warn(warning_preface <> warning)
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
    end
  end
end
