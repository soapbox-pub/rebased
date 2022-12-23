# Pleroma: A lightweight social networking server
# Copyright © 2017-2022 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Integration.WebsocketClient do
  # https://github.com/phoenixframework/phoenix/blob/master/test/support/websocket_client.exs

  use WebSockex

  @doc """
  Starts the WebSocket server for given ws URL. Received Socket.Message's
  are forwarded to the sender pid
  """
  def start_link(sender, url, headers \\ []) do
    WebSockex.start_link(
      url,
      __MODULE__,
      %{sender: sender},
      extra_headers: headers
    )
  end

  @doc """
  Closes the socket
  """
  def close(socket) do
    send(socket, :close)
  end

  @doc """
  Sends a low-level text message to the client.
  """
  def send_text(server_pid, msg) do
    send(server_pid, {:text, msg})
  end

  @doc false
  @impl true
  def handle_frame(frame, state) do
    send(state.sender, frame)
    {:ok, state}
  end

  @impl true
  def handle_disconnect(conn_status, state) do
    send(state.sender, {:close, conn_status})
    {:ok, state}
  end

  @doc false
  @impl true
  def handle_info({:text, msg}, state) do
    {:reply, {:text, msg}, state}
  end

  @impl true
  def handle_info(:close, _state) do
    {:close, <<>>, "done"}
  end

  @doc false
  @impl true
  def terminate(_reason, _state) do
    :ok
  end
end
