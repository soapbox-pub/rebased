# Pleroma: A lightweight social networking server
# Copyright © 2017-2020 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.GunMock do
  @behaviour Pleroma.Gun

  alias Pleroma.Gun
  alias Pleroma.GunMock

  @impl Gun
  def open('some-domain.com', 443, _) do
    {:ok, conn_pid} = Task.start_link(fn -> Process.sleep(1_000) end)

    Registry.register(GunMock, conn_pid, %{
      origin_scheme: "https",
      origin_host: 'some-domain.com',
      origin_port: 443
    })

    {:ok, conn_pid}
  end

  @impl Gun
  def open(ip, port, _)
      when ip in [{10_755, 10_368, 61_708, 131, 64_206, 45_068, 0, 9_694}, {127, 0, 0, 1}] and
             port in [80, 443] do
    {:ok, conn_pid} = Task.start_link(fn -> Process.sleep(1_000) end)

    scheme = if port == 443, do: "https", else: "http"

    Registry.register(GunMock, conn_pid, %{
      origin_scheme: scheme,
      origin_host: ip,
      origin_port: port
    })

    {:ok, conn_pid}
  end

  @impl Gun
  def open('localhost', 1234, %{
        protocols: [:socks],
        proxy: {:socks5, 'localhost', 1234},
        socks_opts: %{host: 'proxy-socks.com', port: 80, version: 5}
      }) do
    {:ok, conn_pid} = Task.start_link(fn -> Process.sleep(1_000) end)

    Registry.register(GunMock, conn_pid, %{
      origin_scheme: "http",
      origin_host: 'proxy-socks.com',
      origin_port: 80
    })

    {:ok, conn_pid}
  end

  @impl Gun
  def open('localhost', 1234, %{
        protocols: [:socks],
        proxy: {:socks4, 'localhost', 1234},
        socks_opts: %{
          host: 'proxy-socks.com',
          port: 443,
          protocols: [:http2],
          tls_opts: [],
          transport: :tls,
          version: 4
        }
      }) do
    {:ok, conn_pid} = Task.start_link(fn -> Process.sleep(1_000) end)

    Registry.register(GunMock, conn_pid, %{
      origin_scheme: "https",
      origin_host: 'proxy-socks.com',
      origin_port: 443
    })

    {:ok, conn_pid}
  end

  @impl Gun
  def open('gun-not-up.com', 80, _opts), do: {:error, :timeout}

  @impl Gun
  def open('example.com', port, _) when port in [443, 115] do
    {:ok, conn_pid} = Task.start_link(fn -> Process.sleep(1_000) end)

    Registry.register(GunMock, conn_pid, %{
      origin_scheme: "https",
      origin_host: 'example.com',
      origin_port: 443
    })

    {:ok, conn_pid}
  end

  @impl Gun
  def open(domain, 80, _) do
    {:ok, conn_pid} = Task.start_link(fn -> Process.sleep(1_000) end)

    Registry.register(GunMock, conn_pid, %{
      origin_scheme: "http",
      origin_host: domain,
      origin_port: 80
    })

    {:ok, conn_pid}
  end

  @impl Gun
  def open({127, 0, 0, 1}, 8123, _) do
    Task.start_link(fn -> Process.sleep(1_000) end)
  end

  @impl Gun
  def open('localhost', 9050, _) do
    Task.start_link(fn -> Process.sleep(1_000) end)
  end

  @impl Gun
  def await_up(_pid, _timeout), do: {:ok, :http}

  @impl Gun
  def set_owner(_pid, _owner), do: :ok

  @impl Gun
  def connect(pid, %{host: _, port: 80}) do
    ref = make_ref()
    Registry.register(GunMock, ref, pid)
    ref
  end

  @impl Gun
  def connect(pid, %{host: _, port: 443, protocols: [:http2], transport: :tls}) do
    ref = make_ref()
    Registry.register(GunMock, ref, pid)
    ref
  end

  @impl Gun
  def await(pid, ref) do
    [{_, ^pid}] = Registry.lookup(GunMock, ref)
    {:response, :fin, 200, []}
  end

  @impl Gun
  def info(pid) do
    [{_, info}] = Registry.lookup(GunMock, pid)
    info
  end

  @impl Gun
  def close(_pid), do: :ok
end
