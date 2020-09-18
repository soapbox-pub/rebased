# Pleroma: A lightweight social networking server
# Copyright © 2017-2020 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.FedSockets.SocketInfo do
  defstruct origin: nil,
            pid: nil,
            conn_pid: nil,
            state: :default,
            connected_until: nil

  alias Pleroma.Web.FedSockets.SocketInfo
  @default_connection_duration 15 * 60 * 1000

  def build(uri, conn_pid \\ nil) do
    uri
    |> build_origin()
    |> build_pids(conn_pid)
    |> touch()
  end

  def touch(%SocketInfo{} = socket_info),
    do: %{socket_info | connected_until: new_ttl()}

  def connect(%SocketInfo{} = socket_info),
    do: %{socket_info | state: :connected}

  def expired?(%{connected_until: connected_until}),
    do: connected_until < :erlang.monotonic_time(:millisecond)

  def origin(uri),
    do: build_origin(uri).origin

  defp build_pids(socket_info, conn_pid),
    do: struct(socket_info, pid: self(), conn_pid: conn_pid)

  defp build_origin(uri) when is_binary(uri),
    do: uri |> URI.parse() |> build_origin

  defp build_origin(%{host: host, port: nil, scheme: scheme}),
    do: build_origin(%{host: host, port: URI.default_port(scheme)})

  defp build_origin(%{host: host, port: port}),
    do: %SocketInfo{origin: "#{host}:#{port}"}

  defp new_ttl do
    connection_duration =
      Pleroma.Config.get([:fed_sockets, :connection_duration], @default_connection_duration)

    :erlang.monotonic_time(:millisecond) + connection_duration
  end
end
