# Pleroma: A lightweight social networking server
# Copyright © 2017-2022 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.Plugs.RemoteIp do
  @moduledoc """
  This is a shim to call [`RemoteIp`](https://git.pleroma.social/pleroma/remote_ip) but with runtime configuration.
  """

  alias Pleroma.Config
  import Plug.Conn

  @behaviour Plug

  def init(_), do: nil

  def call(%{remote_ip: original_remote_ip} = conn, _) do
    if Config.get([__MODULE__, :enabled]) do
      %{remote_ip: new_remote_ip} = conn = RemoteIp.call(conn, remote_ip_opts())
      assign(conn, :remote_ip_found, original_remote_ip != new_remote_ip)
    else
      conn
    end
  end

  defp remote_ip_opts do
    headers = Config.get([__MODULE__, :headers], []) |> MapSet.new()
    reserved = Config.get([__MODULE__, :reserved], [])

    proxies =
      Config.get([__MODULE__, :proxies], [])
      |> Enum.concat(reserved)
      |> Enum.map(&maybe_add_cidr/1)

    {headers, proxies}
  end

  defp maybe_add_cidr(proxy) when is_binary(proxy) do
    proxy =
      cond do
        "/" in String.codepoints(proxy) -> proxy
        InetCidr.v4?(InetCidr.parse_address!(proxy)) -> proxy <> "/32"
        InetCidr.v6?(InetCidr.parse_address!(proxy)) -> proxy <> "/128"
      end

    InetCidr.parse(proxy, true)
  end
end
