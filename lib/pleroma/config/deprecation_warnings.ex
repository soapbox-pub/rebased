# Pleroma: A lightweight social networking server
# Copyright © 2017-2020 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Config.DeprecationWarnings do
  require Logger
  alias Pleroma.Config

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
  end
end
