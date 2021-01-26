# Pleroma: A lightweight social networking server
# Copyright © 2017-2021 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.Plugs.RemoteIpTest do
  use ExUnit.Case
  use Plug.Test

  alias Pleroma.Web.Plugs.RemoteIp

  import Pleroma.Tests.Helpers, only: [clear_config: 2]

  setup do:
          clear_config(RemoteIp,
            enabled: true,
            headers: ["x-forwarded-for"],
            proxies: [],
            reserved: [
              "127.0.0.0/8",
              "::1/128",
              "fc00::/7",
              "10.0.0.0/8",
              "172.16.0.0/12",
              "192.168.0.0/16"
            ]
          )

  test "disabled" do
    clear_config(RemoteIp, enabled: false)

    %{remote_ip: remote_ip} = conn(:get, "/")

    conn =
      conn(:get, "/")
      |> put_req_header("x-forwarded-for", "1.1.1.1")
      |> RemoteIp.call(nil)

    assert conn.remote_ip == remote_ip
  end

  test "enabled" do
    conn =
      conn(:get, "/")
      |> put_req_header("x-forwarded-for", "1.1.1.1")
      |> RemoteIp.call(nil)

    assert conn.remote_ip == {1, 1, 1, 1}
  end

  test "custom headers" do
    clear_config(RemoteIp, enabled: true, headers: ["cf-connecting-ip"])

    conn =
      conn(:get, "/")
      |> put_req_header("x-forwarded-for", "1.1.1.1")
      |> RemoteIp.call(nil)

    refute conn.remote_ip == {1, 1, 1, 1}

    conn =
      conn(:get, "/")
      |> put_req_header("cf-connecting-ip", "1.1.1.1")
      |> RemoteIp.call(nil)

    assert conn.remote_ip == {1, 1, 1, 1}
  end

  test "custom proxies" do
    conn =
      conn(:get, "/")
      |> put_req_header("x-forwarded-for", "173.245.48.1, 1.1.1.1, 173.245.48.2")
      |> RemoteIp.call(nil)

    refute conn.remote_ip == {1, 1, 1, 1}

    clear_config([RemoteIp, :proxies], ["173.245.48.0/20"])

    conn =
      conn(:get, "/")
      |> put_req_header("x-forwarded-for", "173.245.48.1, 1.1.1.1, 173.245.48.2")
      |> RemoteIp.call(nil)

    assert conn.remote_ip == {1, 1, 1, 1}
  end

  test "proxies set without CIDR format" do
    clear_config([RemoteIp, :proxies], ["173.245.48.1"])

    conn =
      conn(:get, "/")
      |> put_req_header("x-forwarded-for", "173.245.48.1, 1.1.1.1")
      |> RemoteIp.call(nil)

    assert conn.remote_ip == {1, 1, 1, 1}
  end

  test "proxies set `nonsensical` CIDR" do
    clear_config([RemoteIp, :reserved], ["127.0.0.0/8"])
    clear_config([RemoteIp, :proxies], ["10.0.0.3/24"])

    conn =
      conn(:get, "/")
      |> put_req_header("x-forwarded-for", "10.0.0.3, 1.1.1.1")
      |> RemoteIp.call(nil)

    assert conn.remote_ip == {1, 1, 1, 1}
  end
end
