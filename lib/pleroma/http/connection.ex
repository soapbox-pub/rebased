# Pleroma: A lightweight social networking server
# Copyright © 2017-2019 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.HTTP.Connection do
  @moduledoc """
  Configure Tesla.Client with default and customized adapter options.
  """
  @type ip_address :: ipv4_address() | ipv6_address()
  @type ipv4_address :: {0..255, 0..255, 0..255, 0..255}
  @type ipv6_address ::
          {0..65_535, 0..65_535, 0..65_535, 0..65_535, 0..65_535, 0..65_535, 0..65_535, 0..65_535}
  @type proxy_type() :: :socks4 | :socks5
  @type host() :: charlist() | ip_address()

  @defaults [pool: :federation]

  require Logger

  alias Pleroma.Config
  alias Pleroma.HTTP.Adapter

  @doc """
  Merge default connection & adapter options with received ones.
  """

  @spec options(URI.t(), keyword()) :: keyword()
  def options(%URI{} = uri, opts \\ []) do
    @defaults
    |> pool_timeout()
    |> Keyword.merge(opts)
    |> adapter().options(uri)
  end

  defp pool_timeout(opts) do
    timeout =
      Config.get([:pools, opts[:pool], :timeout]) || Config.get([:pools, :default, :timeout])

    Keyword.merge(opts, timeout: timeout)
  end

  @spec after_request(keyword()) :: :ok
  def after_request(opts), do: adapter().after_request(opts)

  defp adapter do
    case Application.get_env(:tesla, :adapter) do
      Tesla.Adapter.Gun -> Adapter.Gun
      Tesla.Adapter.Hackney -> Adapter.Hackney
      _ -> Adapter
    end
  end

  @spec parse_proxy(String.t() | tuple() | nil) ::
          {:ok, host(), pos_integer()}
          | {:ok, proxy_type(), host(), pos_integer()}
          | {:error, atom()}
          | nil

  def parse_proxy(nil), do: nil

  def parse_proxy(proxy) when is_binary(proxy) do
    with [host, port] <- String.split(proxy, ":"),
         {port, ""} <- Integer.parse(port) do
      {:ok, parse_host(host), port}
    else
      {_, _} ->
        Logger.warn("parsing port in proxy fail #{inspect(proxy)}")
        {:error, :error_parsing_port_in_proxy}

      :error ->
        Logger.warn("parsing port in proxy fail #{inspect(proxy)}")
        {:error, :error_parsing_port_in_proxy}

      _ ->
        Logger.warn("parsing proxy fail #{inspect(proxy)}")
        {:error, :error_parsing_proxy}
    end
  end

  def parse_proxy(proxy) when is_tuple(proxy) do
    with {type, host, port} <- proxy do
      {:ok, type, parse_host(host), port}
    else
      _ ->
        Logger.warn("parsing proxy fail #{inspect(proxy)}")
        {:error, :error_parsing_proxy}
    end
  end

  @spec parse_host(String.t() | atom() | charlist()) :: charlist() | ip_address()
  def parse_host(host) when is_list(host), do: host
  def parse_host(host) when is_atom(host), do: to_charlist(host)

  def parse_host(host) when is_binary(host) do
    host = to_charlist(host)

    case :inet.parse_address(host) do
      {:error, :einval} -> host
      {:ok, ip} -> ip
    end
  end
end
