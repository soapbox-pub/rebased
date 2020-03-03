# Pleroma: A lightweight social networking server
# Copyright © 2017-2019 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.HTTP.Adapter do
  alias Pleroma.HTTP.Connection

  @type proxy ::
          {Connection.host(), pos_integer()}
          | {Connection.proxy_type(), pos_integer()}
  @type host_type :: :domain | :ip

  @callback options(keyword(), URI.t()) :: keyword()
  @callback after_request(keyword()) :: :ok

  @spec options(keyword(), URI.t()) :: keyword()
  def options(opts, _uri) do
    proxy = Pleroma.Config.get([:http, :proxy_url], nil)
    maybe_add_proxy(opts, format_proxy(proxy))
  end

  @spec maybe_get_conn(URI.t(), keyword()) :: keyword()
  def maybe_get_conn(_uri, opts), do: opts

  @spec after_request(keyword()) :: :ok
  def after_request(_opts), do: :ok

  @spec format_proxy(String.t() | tuple() | nil) :: proxy() | nil
  def format_proxy(nil), do: nil

  def format_proxy(proxy_url) do
    with {:ok, host, port} <- Connection.parse_proxy(proxy_url) do
      {host, port}
    else
      {:ok, type, host, port} -> {type, host, port}
      _ -> nil
    end
  end

  @spec maybe_add_proxy(keyword(), proxy() | nil) :: keyword()
  def maybe_add_proxy(opts, nil), do: opts
  def maybe_add_proxy(opts, proxy), do: Keyword.put_new(opts, :proxy, proxy)

  @spec domain_or_fallback(String.t()) :: charlist()
  def domain_or_fallback(host) do
    case domain_or_ip(host) do
      {:domain, domain} -> domain
      {:ip, _ip} -> to_charlist(host)
    end
  end

  @spec domain_or_ip(String.t()) :: {host_type(), Connection.host()}
  def domain_or_ip(host) do
    charlist = to_charlist(host)

    case :inet.parse_address(charlist) do
      {:error, :einval} ->
        {:domain, :idna.encode(charlist)}

      {:ok, ip} ->
        {:ip, ip}
    end
  end
end
