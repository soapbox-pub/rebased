# Pleroma: A lightweight social networking server
# Copyright © 2017-2020 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Gun.Conn do
  @moduledoc """
  Struct for gun connection data
  """
  alias Pleroma.Gun
  alias Pleroma.Pool.Connections

  require Logger

  @type gun_state :: :up | :down
  @type conn_state :: :active | :idle

  @type t :: %__MODULE__{
          conn: pid(),
          gun_state: gun_state(),
          conn_state: conn_state(),
          used_by: [pid()],
          last_reference: pos_integer(),
          crf: float(),
          retries: pos_integer()
        }

  defstruct conn: nil,
            gun_state: :open,
            conn_state: :init,
            used_by: [],
            last_reference: 0,
            crf: 1,
            retries: 0

  @spec open(String.t() | URI.t(), atom(), keyword()) :: :ok | nil
  def open(url, name, opts \\ [])
  def open(url, name, opts) when is_binary(url), do: open(URI.parse(url), name, opts)

  def open(%URI{} = uri, name, opts) do
    pool_opts = Pleroma.Config.get([:connections_pool], [])

    opts =
      opts
      |> Enum.into(%{})
      |> Map.put_new(:retry, pool_opts[:retry] || 1)
      |> Map.put_new(:retry_timeout, pool_opts[:retry_timeout] || 1000)
      |> Map.put_new(:await_up_timeout, pool_opts[:await_up_timeout] || 5_000)

    key = "#{uri.scheme}:#{uri.host}:#{uri.port}"

    Logger.debug("opening new connection #{Connections.compose_uri_log(uri)}")

    conn_pid =
      if Connections.count(name) < opts[:max_connection] do
        do_open(uri, opts)
      else
        close_least_used_and_do_open(name, uri, opts)
      end

    if is_pid(conn_pid) do
      conn = %Pleroma.Gun.Conn{
        conn: conn_pid,
        gun_state: :up,
        conn_state: :active,
        last_reference: :os.system_time(:second)
      }

      :ok = Gun.set_owner(conn_pid, Process.whereis(name))
      Connections.add_conn(name, key, conn)
    end
  end

  defp do_open(uri, %{proxy: {proxy_host, proxy_port}} = opts) do
    connect_opts =
      uri
      |> destination_opts()
      |> add_http2_opts(uri.scheme, Map.get(opts, :tls_opts, []))

    with open_opts <- Map.delete(opts, :tls_opts),
         {:ok, conn} <- Gun.open(proxy_host, proxy_port, open_opts),
         {:ok, _} <- Gun.await_up(conn, opts[:await_up_timeout]),
         stream <- Gun.connect(conn, connect_opts),
         {:response, :fin, 200, _} <- Gun.await(conn, stream) do
      conn
    else
      error ->
        Logger.warn(
          "Received error on opening connection with http proxy #{
            Connections.compose_uri_log(uri)
          } #{inspect(error)}"
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
         {:ok, _} <- Gun.await_up(conn, opts[:await_up_timeout]) do
      conn
    else
      error ->
        Logger.warn(
          "Received error on opening connection with socks proxy #{
            Connections.compose_uri_log(uri)
          } #{inspect(error)}"
        )

        error
    end
  end

  defp do_open(%URI{host: host, port: port} = uri, opts) do
    host = Pleroma.HTTP.Connection.parse_host(host)

    with {:ok, conn} <- Gun.open(host, port, opts),
         {:ok, _} <- Gun.await_up(conn, opts[:await_up_timeout]) do
      conn
    else
      error ->
        Logger.warn(
          "Received error on opening connection #{Connections.compose_uri_log(uri)} #{
            inspect(error)
          }"
        )

        error
    end
  end

  defp destination_opts(%URI{host: host, port: port}) do
    host = Pleroma.HTTP.Connection.parse_host(host)
    %{host: host, port: port}
  end

  defp add_http2_opts(opts, "https", tls_opts) do
    Map.merge(opts, %{protocols: [:http2], transport: :tls, tls_opts: tls_opts})
  end

  defp add_http2_opts(opts, _, _), do: opts

  defp close_least_used_and_do_open(name, uri, opts) do
    Logger.debug("try to open conn #{Connections.compose_uri_log(uri)}")

    with [{close_key, least_used} | _conns] <-
           Connections.get_unused_conns(name),
         :ok <- Gun.close(least_used.conn) do
      Connections.remove_conn(name, close_key)

      do_open(uri, opts)
    else
      [] -> {:error, :pool_overflowed}
    end
  end
end
