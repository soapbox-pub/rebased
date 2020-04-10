# Pleroma: A lightweight social networking server
# Copyright © 2017-2020 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.HTTP.AdapterHelper do
  alias Pleroma.HTTP.Connection

  @type proxy ::
          {Connection.host(), pos_integer()}
          | {Connection.proxy_type(), Connection.host(), pos_integer()}

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
    case Connection.parse_proxy(proxy_url) do
      {:ok, host, port} -> {host, port}
      {:ok, type, host, port} -> {type, host, port}
      _ -> nil
    end
  end

  @spec maybe_add_proxy(keyword(), proxy() | nil) :: keyword()
  def maybe_add_proxy(opts, nil), do: opts
  def maybe_add_proxy(opts, proxy), do: Keyword.put_new(opts, :proxy, proxy)
end
