# Pleroma: A lightweight social networking server
# Copyright © 2017-2020 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Integration.WebsocketClient do
  # https://github.com/phoenixframework/phoenix/blob/master/test/support/websocket_client.exs

  @doc """
  Starts the WebSocket server for given ws URL. Received Socket.Message's
  are forwarded to the sender pid
  """
  def start_link(sender, url, headers \\ []) do
    :crypto.start()
    :ssl.start()

    :websocket_client.start_link(
      String.to_charlist(url),
      __MODULE__,
      [sender],
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
  def init([sender], _conn_state) do
    {:ok, %{sender: sender}}
  end

  @doc false
  def websocket_handle(frame, _conn_state, state) do
    send(state.sender, frame)
    {:ok, state}
  end

  @doc false
  def websocket_info({:text, msg}, _conn_state, state) do
    {:reply, {:text, msg}, state}
  end

  def websocket_info(:close, _conn_state, _state) do
    {:close, <<>>, "done"}
  end

  @doc false
  def websocket_terminate(_reason, _conn_state, _state) do
    :ok
  end
end
