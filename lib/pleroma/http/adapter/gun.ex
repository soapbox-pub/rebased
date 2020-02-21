# Pleroma: A lightweight social networking server
# Copyright © 2017-2019 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.HTTP.Adapter.Gun do
  @behaviour Pleroma.HTTP.Adapter

  alias Pleroma.HTTP.Adapter

  require Logger

  alias Pleroma.Pool.Connections

  @defaults [
    connect_timeout: 20_000,
    domain_lookup_timeout: 5_000,
    tls_handshake_timeout: 5_000,
    retry: 0,
    await_up_timeout: 5_000
  ]

  @spec options(keyword(), URI.t()) :: keyword()
  def options(connection_opts \\ [], %URI{} = uri) do
    proxy = Pleroma.Config.get([:http, :proxy_url], nil)

    @defaults
    |> Keyword.merge(Pleroma.Config.get([:http, :adapter], []))
    |> add_original(uri)
    |> add_scheme_opts(uri)
    |> Adapter.maybe_add_proxy(Adapter.format_proxy(proxy))
    |> maybe_get_conn(uri, connection_opts)
  end

  @spec after_request(keyword()) :: :ok
  def after_request(opts) do
    with conn when not is_nil(conn) <- opts[:conn],
         body_as when body_as != :chunks <- opts[:body_as] do
      Connections.checkout(conn, self(), :gun_connections)
    end

    :ok
  end

  defp add_original(opts, %URI{host: host, port: port}) do
    formatted_host = Adapter.domain_or_fallback(host)

    Keyword.put(opts, :original, "#{formatted_host}:#{port}")
  end

  defp add_scheme_opts(opts, %URI{scheme: "http"}), do: opts

  defp add_scheme_opts(opts, %URI{scheme: "https", host: host, port: port}) do
    adapter_opts = [
      certificates_verification: true,
      tls_opts: [
        verify: :verify_peer,
        cacertfile: CAStore.file_path(),
        depth: 20,
        reuse_sessions: false,
        verify_fun:
          {&:ssl_verify_hostname.verify_fun/3, [check_hostname: Adapter.domain_or_fallback(host)]},
        log_level: :warning
      ]
    ]

    adapter_opts =
      if port != 443 do
        Keyword.put(adapter_opts, :transport, :tls)
      else
        adapter_opts
      end

    Keyword.merge(opts, adapter_opts)
  end

  defp maybe_get_conn(adapter_opts, uri, connection_opts) do
    {receive_conn?, opts} =
      adapter_opts
      |> Keyword.merge(connection_opts)
      |> Keyword.pop(:receive_conn, true)

    if Connections.alive?(:gun_connections) and receive_conn? do
      try_to_get_conn(uri, opts)
    else
      opts
    end
  end

  defp try_to_get_conn(uri, opts) do
    try do
      case Connections.checkin(uri, :gun_connections) do
        nil ->
          Logger.debug(
            "Gun connections pool checkin was not successful. Trying to open conn for next request."
          )

          :ok = Connections.open_conn(uri, :gun_connections, opts)
          opts

        conn when is_pid(conn) ->
          Logger.debug(
            "received conn #{inspect(conn)} #{uri.scheme}://#{Connections.compose_uri(uri)}"
          )

          opts
          |> Keyword.put(:conn, conn)
          |> Keyword.put(:close_conn, false)
      end
    rescue
      error ->
        Logger.warn(
          "Gun connections pool checkin caused error #{uri.scheme}://#{
            Connections.compose_uri(uri)
          } #{inspect(error)}"
        )

        opts
    catch
      :exit, {:timeout, {_, operation, [_, {method, _}, _]}} ->
        {:message_queue_len, messages_len} =
          :gun_connections
          |> Process.whereis()
          |> Process.info(:message_queue_len)

        Logger.warn(
          "Gun connections pool checkin with timeout error for #{operation} #{method} #{
            uri.scheme
          }://#{Connections.compose_uri(uri)}. Messages length: #{messages_len}"
        )

        opts

      :exit, error ->
        Logger.warn(
          "Gun pool checkin exited with error #{uri.scheme}://#{Connections.compose_uri(uri)} #{
            inspect(error)
          }"
        )

        opts
    end
  end
end
