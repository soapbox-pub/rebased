# Pleroma: A lightweight social networking server
# Copyright © 2017-2019 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Phoenix.Transports.WebSocket.Raw do
  import Plug.Conn,
    only: [
      fetch_query_params: 1,
      send_resp: 3
    ]

  alias Phoenix.Socket.Transport

  def default_config do
    [
      timeout: 60_000,
      transport_log: false,
      cowboy: Phoenix.Endpoint.CowboyWebSocket
    ]
  end

  def init(%Plug.Conn{method: "GET"} = conn, {endpoint, handler, transport}) do
    {_, opts} = handler.__transport__(transport)

    conn =
      conn
      |> fetch_query_params
      |> Transport.transport_log(opts[:transport_log])
      |> Transport.force_ssl(handler, endpoint, opts)
      |> Transport.check_origin(handler, endpoint, opts)

    case conn do
      %{halted: false} = conn ->
        case Transport.connect(endpoint, handler, transport, __MODULE__, nil, conn.params) do
          {:ok, socket} ->
            {:ok, conn, {__MODULE__, {socket, opts}}}

          :error ->
            send_resp(conn, :forbidden, "")
            {:error, conn}
        end

      _ ->
        {:error, conn}
    end
  end

  def init(conn, _) do
    send_resp(conn, :bad_request, "")
    {:error, conn}
  end

  def ws_init({socket, config}) do
    Process.flag(:trap_exit, true)
    {:ok, %{socket: socket}, config[:timeout]}
  end

  def ws_handle(op, data, state) do
    state.socket.handler
    |> apply(:handle, [op, data, state])
    |> case do
      {op, data} ->
        {:reply, {op, data}, state}

      {op, data, state} ->
        {:reply, {op, data}, state}

      %{} = state ->
        {:ok, state}

      _ ->
        {:ok, state}
    end
  end

  def ws_info({_, _} = tuple, state) do
    {:reply, tuple, state}
  end

  def ws_info(_tuple, state), do: {:ok, state}

  def ws_close(state) do
    ws_handle(:closed, :normal, state)
  end

  def ws_terminate(reason, state) do
    ws_handle(:closed, reason, state)
  end
end
