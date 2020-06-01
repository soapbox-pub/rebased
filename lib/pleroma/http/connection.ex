# Pleroma: A lightweight social networking server
# Copyright © 2017-2020 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.HTTP.Connection do
  @moduledoc """
  Configure Tesla.Client with default and customized adapter options.
  """

  alias Pleroma.Config
  alias Pleroma.HTTP.AdapterHelper

  require Logger

  @defaults [pool: :federation]

  @type ip_address :: ipv4_address() | ipv6_address()
  @type ipv4_address :: {0..255, 0..255, 0..255, 0..255}
  @type ipv6_address ::
          {0..65_535, 0..65_535, 0..65_535, 0..65_535, 0..65_535, 0..65_535, 0..65_535, 0..65_535}
  @type proxy_type() :: :socks4 | :socks5
  @type host() :: charlist() | ip_address()

  @doc """
  Merge default connection & adapter options with received ones.
  """

  @spec options(URI.t(), keyword()) :: keyword()
  def options(%URI{} = uri, opts \\ []) do
    @defaults
    |> pool_timeout()
    |> Keyword.merge(opts)
    |> adapter_helper().options(uri)
  end

  defp pool_timeout(opts) do
    {config_key, default} =
      if adapter() == Tesla.Adapter.Gun do
        {:pools, Config.get([:pools, :default, :timeout])}
      else
        {:hackney_pools, 10_000}
      end

    timeout = Config.get([config_key, opts[:pool], :timeout], default)

    Keyword.merge(opts, timeout: timeout)
  end

  @spec after_request(keyword()) :: :ok
  def after_request(opts), do: adapter_helper().after_request(opts)

  defp adapter, do: Application.get_env(:tesla, :adapter)

  defp adapter_helper do
    case adapter() do
      Tesla.Adapter.Gun -> AdapterHelper.Gun
      Tesla.Adapter.Hackney -> AdapterHelper.Hackney
      _ -> AdapterHelper
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
        Logger.warn("Parsing port failed #{inspect(proxy)}")
        {:error, :invalid_proxy_port}

      :error ->
        Logger.warn("Parsing port failed #{inspect(proxy)}")
        {:error, :invalid_proxy_port}

      _ ->
        Logger.warn("Parsing proxy failed #{inspect(proxy)}")
        {:error, :invalid_proxy}
    end
  end

  def parse_proxy(proxy) when is_tuple(proxy) do
    with {type, host, port} <- proxy do
      {:ok, type, parse_host(host), port}
    else
      _ ->
        Logger.warn("Parsing proxy failed #{inspect(proxy)}")
        {:error, :invalid_proxy}
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

  @spec format_host(String.t()) :: charlist()
  def format_host(host) do
    host_charlist = to_charlist(host)

    case :inet.parse_address(host_charlist) do
      {:error, :einval} ->
        :idna.encode(host_charlist)

      {:ok, _ip} ->
        host_charlist
    end
  end
end
