# Pleroma: A lightweight social networking server
# Copyright © 2017-2020 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.HTTP.AdapterHelper.Gun do
  @behaviour Pleroma.HTTP.AdapterHelper

  alias Pleroma.Gun.ConnectionPool
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

  @spec options(keyword(), URI.t()) :: keyword()
  def options(incoming_opts \\ [], %URI{} = uri) do
    proxy =
      Pleroma.Config.get([:http, :proxy_url])
      |> AdapterHelper.format_proxy()

    config_opts = Pleroma.Config.get([:http, :adapter], [])

    @defaults
    |> Keyword.merge(config_opts)
    |> add_scheme_opts(uri)
    |> AdapterHelper.maybe_add_proxy(proxy)
    |> Keyword.merge(incoming_opts)
  end

  defp add_scheme_opts(opts, %{scheme: "http"}), do: opts

  defp add_scheme_opts(opts, %{scheme: "https"}) do
    opts
    |> Keyword.put(:certificates_verification, true)
    |> Keyword.put(:tls_opts,
      log_level: :warning,
      customize_hostname_check: [match_fun: &ssl_match_fun/2]
    )
  end

  # ssl_match_fun is adapted from [Mint](https://github.com/elixir-mint/mint)
  # Copyright 2018 Eric Meadows-Jönsson and Andrea Leopardi

  # Wildcard domain handling for DNS ID entries in the subjectAltName X.509
  # extension. Note that this is a subset of the wildcard patterns implemented
  # by OTP when matching against the subject CN attribute, but this is the only
  # wildcard usage defined by the CA/Browser Forum's Baseline Requirements, and
  # therefore the only pattern used in commercially issued certificates.
  defp ssl_match_fun({:dns_id, reference}, {:dNSName, [?*, ?. | presented]}) do
    case domain_without_host(reference) do
      '' ->
        :default

      domain ->
        :string.casefold(domain) == :string.casefold(presented)
    end
  end

  defp ssl_match_fun(_reference, _presented), do: :default

  defp domain_without_host([]), do: []
  defp domain_without_host([?. | domain]), do: domain
  defp domain_without_host([_ | more]), do: domain_without_host(more)

  @spec get_conn(URI.t(), keyword()) :: {:ok, keyword()} | {:error, atom()}
  def get_conn(uri, opts) do
    case ConnectionPool.get_conn(uri, opts) do
      {:ok, conn_pid} -> {:ok, Keyword.merge(opts, conn: conn_pid, close_conn: false)}
      err -> err
    end
  end

  @prefix Pleroma.Gun.ConnectionPool
  def limiter_setup do
    wait = Pleroma.Config.get([:connections_pool, :connection_acquisition_wait])
    retries = Pleroma.Config.get([:connections_pool, :connection_acquisition_retries])

    :pools
    |> Pleroma.Config.get([])
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
        e -> raise e
      end
    end)

    :ok
  end
end
