# Pleroma: A lightweight social networking server
# Copyright © 2017-2019 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Plugs.RemoteIpTest do
  use ExUnit.Case, async: true
  use Plug.Test

  alias Pleroma.Plugs.RemoteIp

  test "disabled" do
    Pleroma.Config.put(RemoteIp, enabled: false)

    %{remote_ip: remote_ip} = conn(:get, "/")

    conn =
      conn(:get, "/")
      |> put_req_header("x-forwarded-for", "1.1.1.1")
      |> RemoteIp.call(nil)

    assert conn.remote_ip == remote_ip
  end

  test "enabled" do
    Pleroma.Config.put(RemoteIp, enabled: true)

    conn =
      conn(:get, "/")
      |> put_req_header("x-forwarded-for", "1.1.1.1")
      |> RemoteIp.call(nil)

    assert conn.remote_ip == {1, 1, 1, 1}
  end

  test "custom headers" do
    Pleroma.Config.put(RemoteIp, enabled: true, headers: ["cf-connecting-ip"])

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
    Pleroma.Config.put(RemoteIp, enabled: true)

    conn =
      conn(:get, "/")
      |> put_req_header("x-forwarded-for", "173.245.48.1, 1.1.1.1, 173.245.48.2")
      |> RemoteIp.call(nil)

    refute conn.remote_ip == {1, 1, 1, 1}

    Pleroma.Config.put([RemoteIp, :proxies], ["173.245.48.0/20"])

    conn =
      conn(:get, "/")
      |> put_req_header("x-forwarded-for", "173.245.48.1, 1.1.1.1, 173.245.48.2")
      |> RemoteIp.call(nil)

    assert conn.remote_ip == {1, 1, 1, 1}
  end
end
