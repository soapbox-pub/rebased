# Pleroma: A lightweight social networking server
# Copyright © 2017-2020 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.FedSockets.IncomingHandler do
  require Logger

  alias Pleroma.Web.FedSockets.FedRegistry
  alias Pleroma.Web.FedSockets.FedSocket
  alias Pleroma.Web.FedSockets.SocketInfo

  import HTTPSignatures, only: [validate_conn: 1, split_signature: 1]

  @behaviour :cowboy_websocket

  def init(req, state) do
    shake = FedSocket.shake()

    with true <- Pleroma.Config.get([:fed_sockets, :enabled]),
         sec_protocol <- :cowboy_req.header("sec-websocket-protocol", req, nil),
         headers = %{"(request-target)" => ^shake} <- :cowboy_req.headers(req),
         true <- validate_conn(%{req_headers: headers}),
         %{"keyId" => origin} <- split_signature(headers["signature"]) do
      req =
        if is_nil(sec_protocol) do
          req
        else
          :cowboy_req.set_resp_header("sec-websocket-protocol", sec_protocol, req)
        end

      {:cowboy_websocket, req, %{origin: origin}, %{}}
    else
      _ ->
        {:ok, req, state}
    end
  end

  def websocket_init(%{origin: origin}) do
    case FedRegistry.add_fed_socket(origin) do
      {:ok, socket_info} ->
        {:ok, socket_info}

      e ->
        Logger.error("FedSocket websocket_init failed - #{inspect(e)}")
        {:error, inspect(e)}
    end
  end

  # Use the ping to  check if the connection should be expired
  def websocket_handle(:ping, socket_info) do
    if SocketInfo.expired?(socket_info) do
      {:stop, socket_info}
    else
      {:ok, socket_info, :hibernate}
    end
  end

  def websocket_handle({:text, data}, socket_info) do
    socket_info = SocketInfo.touch(socket_info)

    case FedSocket.receive_package(socket_info, data) do
      {:noreply, _} ->
        {:ok, socket_info}

      {:reply, reply} ->
        {:reply, {:text, Jason.encode!(reply)}, socket_info}

      {:error, reason} ->
        Logger.error("incoming error - receive_package: #{inspect(reason)}")
        {:ok, socket_info}
    end
  end

  def websocket_info({:send, message}, socket_info) do
    socket_info = SocketInfo.touch(socket_info)

    {:reply, {:text, message}, socket_info}
  end

  def websocket_info(:close, state) do
    {:stop, state}
  end

  def websocket_info(message, state) do
    Logger.debug("#{__MODULE__} unknown message #{inspect(message)}")
    {:ok, state}
  end
end
