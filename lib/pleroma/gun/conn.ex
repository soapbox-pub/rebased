# Pleroma: A lightweight social networking server
# Copyright © 2017-2022 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Gun.Conn do
  alias Pleroma.Gun

  require Logger

  def open(%URI{} = uri, opts) do
    pool_opts = Pleroma.Config.get([:connections_pool], [])

    opts =
      opts
      |> Enum.into(%{})
      |> Map.put_new(:connect_timeout, pool_opts[:connect_timeout] || 5_000)
      |> Map.put_new(:supervise, false)
      |> maybe_add_tls_opts(uri)

    do_open(uri, opts)
  end

  defp maybe_add_tls_opts(opts, %URI{scheme: "http"}), do: opts

  defp maybe_add_tls_opts(opts, %URI{scheme: "https"}) do
    tls_opts = [
      verify: :verify_peer,
      cacertfile: CAStore.file_path(),
      depth: 20,
      reuse_sessions: false,
      log_level: :warning,
      customize_hostname_check: [match_fun: :public_key.pkix_verify_hostname_match_fun(:https)]
    ]

    tls_opts =
      if Keyword.keyword?(opts[:tls_opts]) do
        Keyword.merge(tls_opts, opts[:tls_opts])
      else
        tls_opts
      end

    Map.put(opts, :tls_opts, tls_opts)
  end

  defp do_open(uri, %{proxy: {proxy_host, proxy_port}} = opts) do
    connect_opts =
      uri
      |> destination_opts()
      |> add_http2_opts(uri.scheme, Map.get(opts, :tls_opts, []))

    with open_opts <- Map.delete(opts, :tls_opts),
         {:ok, conn} <- Gun.open(proxy_host, proxy_port, open_opts),
         {:ok, protocol} <- Gun.await_up(conn, opts[:connect_timeout]),
         stream <- Gun.connect(conn, connect_opts),
         {:response, :fin, 200, _} <- Gun.await(conn, stream) do
      {:ok, conn, protocol}
    else
      error ->
        Logger.warn(
          "Opening proxied connection to #{compose_uri_log(uri)} failed with error #{inspect(error)}"
        )

        error
    end
  end

  defp do_open(uri, %{proxy: {proxy_type, proxy_host, proxy_port}} = opts) do
    version =
      proxy_type
      |> to_string()
      |> String.last()
      |> case do
        "4" -> 4
        _ -> 5
      end

    socks_opts =
      uri
      |> destination_opts()
      |> add_http2_opts(uri.scheme, Map.get(opts, :tls_opts, []))
      |> Map.put(:version, version)

    opts =
      opts
      |> Map.put(:protocols, [:socks])
      |> Map.put(:socks_opts, socks_opts)

    with {:ok, conn} <- Gun.open(proxy_host, proxy_port, opts),
         {:ok, protocol} <- Gun.await_up(conn, opts[:connect_timeout]) do
      {:ok, conn, protocol}
    else
      error ->
        Logger.warn(
          "Opening socks proxied connection to #{compose_uri_log(uri)} failed with error #{inspect(error)}"
        )

        error
    end
  end

  defp do_open(%URI{host: host, port: port} = uri, opts) do
    host = Pleroma.HTTP.AdapterHelper.parse_host(host)

    with {:ok, conn} <- Gun.open(host, port, opts),
         {:ok, protocol} <- Gun.await_up(conn, opts[:connect_timeout]) do
      {:ok, conn, protocol}
    else
      error ->
        Logger.warn(
          "Opening connection to #{compose_uri_log(uri)} failed with error #{inspect(error)}"
        )

        error
    end
  end

  defp destination_opts(%URI{host: host, port: port}) do
    host = Pleroma.HTTP.AdapterHelper.parse_host(host)
    %{host: host, port: port}
  end

  defp add_http2_opts(opts, "https", tls_opts) do
    Map.merge(opts, %{protocols: [:http2], transport: :tls, tls_opts: tls_opts})
  end

  defp add_http2_opts(opts, _, _), do: opts

  def compose_uri_log(%URI{scheme: scheme, host: host, path: path}) do
    "#{scheme}://#{host}#{path}"
  end
end
