# Pleroma: A lightweight social networking server
# Copyright © 2017-2019 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Plugs.RemoteIp do
  @moduledoc """
  This is a shim to call [`RemoteIp`](https://git.pleroma.social/pleroma/remote_ip) but with runtime configuration.
  """

  @behaviour Plug

  @headers ~w[
    x-forwarded-for
  ]

  # https://en.wikipedia.org/wiki/Localhost
  # https://en.wikipedia.org/wiki/Private_network
  @reserved ~w[
    127.0.0.0/8
    ::1/128
    fc00::/7
    10.0.0.0/8
    172.16.0.0/12
    192.168.0.0/16
  ]

  def init(_), do: nil

  def call(conn, _) do
    config = Pleroma.Config.get(__MODULE__, [])

    if Keyword.get(config, :enabled, false) do
      RemoteIp.call(conn, remote_ip_opts(config))
    else
      conn
    end
  end

  defp remote_ip_opts(config) do
    headers = config |> Keyword.get(:headers, @headers) |> MapSet.new()
    reserved = Keyword.get(config, :reserved, @reserved)

    proxies =
      config
      |> Keyword.get(:proxies, [])
      |> Enum.concat(reserved)
      |> Enum.map(&InetCidr.parse/1)

    {headers, proxies}
  end
end
