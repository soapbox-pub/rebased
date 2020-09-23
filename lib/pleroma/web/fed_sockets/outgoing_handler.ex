# Pleroma: A lightweight social networking server
# Copyright © 2017-2020 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.FedSockets.OutgoingHandler do
  use GenServer

  require Logger

  alias Pleroma.Application
  alias Pleroma.Web.ActivityPub.InternalFetchActor
  alias Pleroma.Web.FedSockets
  alias Pleroma.Web.FedSockets.FedRegistry
  alias Pleroma.Web.FedSockets.FedSocket
  alias Pleroma.Web.FedSockets.SocketInfo

  def start_link(uri) do
    GenServer.start_link(__MODULE__, %{uri: uri})
  end

  def init(%{uri: uri}) do
    case initiate_connection(uri) do
      {:ok, ws_origin, conn_pid} ->
        FedRegistry.add_fed_socket(ws_origin, conn_pid)

      {:error, reason} ->
        Logger.debug("Outgoing connection failed - #{inspect(reason)}")
        :ignore
    end
  end

  def handle_info({:gun_ws, conn_pid, _ref, {:text, data}}, socket_info) do
    socket_info = SocketInfo.touch(socket_info)

    case FedSocket.receive_package(socket_info, data) do
      {:noreply, _} ->
        {:noreply, socket_info}

      {:reply, reply} ->
        :gun.ws_send(conn_pid, {:text, Jason.encode!(reply)})
        {:noreply, socket_info}

      {:error, reason} ->
        Logger.error("incoming error - receive_package: #{inspect(reason)}")
        {:noreply, socket_info}
    end
  end

  def handle_info(:close, state) do
    Logger.debug("Sending close frame !!!!!!!")
    {:close, state}
  end

  def handle_info({:gun_down, _pid, _prot, :closed, _}, state) do
    {:stop, :normal, state}
  end

  def handle_info({:send, data}, %{conn_pid: conn_pid} = socket_info) do
    socket_info = SocketInfo.touch(socket_info)
    :gun.ws_send(conn_pid, {:text, data})
    {:noreply, socket_info}
  end

  def handle_info({:gun_ws, _, _, :pong}, state) do
    {:noreply, state, :hibernate}
  end

  def handle_info(msg, state) do
    Logger.debug("#{__MODULE__} unhandled event #{inspect(msg)}")
    {:noreply, state}
  end

  def terminate(reason, state) do
    Logger.debug(
      "#{__MODULE__} terminating outgoing connection for #{inspect(state)} for #{inspect(reason)}"
    )

    {:ok, state}
  end

  def initiate_connection(uri) do
    ws_uri =
      uri
      |> SocketInfo.origin()
      |> FedSockets.uri_for_origin()

    %{host: host, port: port, path: path} = URI.parse(ws_uri)

    with {:ok, conn_pid} <- :gun.open(to_charlist(host), port, %{protocols: [:http]}),
         {:ok, _} <- :gun.await_up(conn_pid),
         reference <-
           :gun.get(conn_pid, to_charlist(path), [
             {'user-agent', to_charlist(Application.user_agent())}
           ]),
         {:response, :fin, 204, _} <- :gun.await(conn_pid, reference),
         headers <- build_headers(uri),
         ref <- :gun.ws_upgrade(conn_pid, to_charlist(path), headers, %{silence_pings: false}) do
      receive do
        {:gun_upgrade, ^conn_pid, ^ref, [<<"websocket">>], _} ->
          {:ok, ws_uri, conn_pid}
      after
        15_000 ->
          Logger.debug("Fedsocket timeout connecting to #{inspect(uri)}")
          {:error, :timeout}
      end
    else
      {:response, :nofin, 404, _} ->
        {:error, :fedsockets_not_supported}

      e ->
        Logger.debug("Fedsocket error connecting to #{inspect(uri)}")
        {:error, e}
    end
  end

  defp build_headers(uri) do
    host_for_sig = uri |> URI.parse() |> host_signature()

    shake = FedSocket.shake()
    digest = "SHA-256=" <> (:crypto.hash(:sha256, shake) |> Base.encode64())
    date = Pleroma.Signature.signed_date()
    shake_size = byte_size(shake)

    signature_opts = %{
      "(request-target)": shake,
      "content-length": to_charlist("#{shake_size}"),
      date: date,
      digest: digest,
      host: host_for_sig
    }

    signature = Pleroma.Signature.sign(InternalFetchActor.get_actor(), signature_opts)

    [
      {'signature', to_charlist(signature)},
      {'date', date},
      {'digest', to_charlist(digest)},
      {'content-length', to_charlist("#{shake_size}")},
      {to_charlist("(request-target)"), to_charlist(shake)},
      {'user-agent', to_charlist(Application.user_agent())}
    ]
  end

  defp host_signature(%{host: host, scheme: scheme, port: port}) do
    if port == URI.default_port(scheme) do
      host
    else
      "#{host}:#{port}"
    end
  end
end
