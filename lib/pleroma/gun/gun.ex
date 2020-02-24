# Pleroma: A lightweight social networking server
# Copyright © 2017-2019 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Gun do
  @behaviour Pleroma.Gun.API

  alias Pleroma.Gun.API

  @gun_keys [
    :connect_timeout,
    :http_opts,
    :http2_opts,
    :protocols,
    :retry,
    :retry_timeout,
    :trace,
    :transport,
    :tls_opts,
    :tcp_opts,
    :socks_opts,
    :ws_opts
  ]

  @impl API
  def open(host, port, opts \\ %{}), do: :gun.open(host, port, Map.take(opts, @gun_keys))

  @impl API
  defdelegate info(pid), to: :gun

  @impl API
  defdelegate close(pid), to: :gun

  @impl API
  defdelegate await_up(pid, timeout \\ 5_000), to: :gun

  @impl API
  defdelegate connect(pid, opts), to: :gun

  @impl API
  defdelegate await(pid, ref), to: :gun

  @spec flush(pid() | reference()) :: :ok
  defdelegate flush(pid), to: :gun

  @impl API
  defdelegate set_owner(pid, owner), to: :gun
end
