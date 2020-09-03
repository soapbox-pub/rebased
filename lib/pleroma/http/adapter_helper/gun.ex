# Pleroma: A lightweight social networking server
# Copyright © 2017-2020 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.HTTP.AdapterHelper.Gun do
  @behaviour Pleroma.HTTP.AdapterHelper

  alias Pleroma.Config
  alias Pleroma.HTTP.AdapterHelper

  require Logger

  @defaults [
    connect_timeout: 5_000,
    domain_lookup_timeout: 5_000,
    tls_handshake_timeout: 5_000,
    retry: 1,
    retry_timeout: 1000,
    await_up_timeout: 5_000
  ]

  @type pool() :: :federation | :upload | :media | :default

  @spec options(keyword(), URI.t()) :: keyword()
  def options(incoming_opts \\ [], %URI{} = uri) do
    proxy =
      [:http, :proxy_url]
      |> Config.get()
      |> AdapterHelper.format_proxy()

    config_opts = Config.get([:http, :adapter], [])

    @defaults
    |> Keyword.merge(config_opts)
    |> add_scheme_opts(uri)
    |> AdapterHelper.maybe_add_proxy(proxy)
    |> Keyword.merge(incoming_opts)
    |> put_timeout()
  end

  defp add_scheme_opts(opts, %{scheme: "http"}), do: opts

  defp add_scheme_opts(opts, %{scheme: "https"}) do
    Keyword.put(opts, :certificates_verification, true)
  end

  defp put_timeout(opts) do
    # this is the timeout to receive a message from Gun
    Keyword.put_new(opts, :timeout, pool_timeout(opts[:pool]))
  end

  @spec pool_timeout(pool()) :: non_neg_integer()
  def pool_timeout(pool) do
    default = Config.get([:pools, :default, :timeout], 5_000)

    Config.get([:pools, pool, :timeout], default)
  end

  @prefix Pleroma.Gun.ConnectionPool
  def limiter_setup do
    wait = Config.get([:connections_pool, :connection_acquisition_wait])
    retries = Config.get([:connections_pool, :connection_acquisition_retries])

    :pools
    |> Config.get([])
    |> Enum.each(fn {name, opts} ->
      max_running = Keyword.get(opts, :size, 50)
      max_waiting = Keyword.get(opts, :max_waiting, 10)

      result =
        ConcurrentLimiter.new(:"#{@prefix}.#{name}", max_running, max_waiting,
          wait: wait,
          max_retries: retries
        )

      case result do
        :ok -> :ok
        {:error, :existing} -> :ok
      end
    end)

    :ok
  end
end
