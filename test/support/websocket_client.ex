# Pleroma: A lightweight social networking server
# Copyright © 2017-2022 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Integration.WebsocketClient do
  @moduledoc """
  A WebSocket client used to test Mastodon API streaming

  Based on Phoenix Framework's WebsocketClient
  https://github.com/phoenixframework/phoenix/blob/master/test/support/websocket_client.exs
  """

  use GenServer
  import Kernel, except: [send: 2]

  defstruct [
    :conn,
    :request_ref,
    :websocket,
    :caller,
    :status,
    :resp_headers,
    :sender,
    closing?: false
  ]

  @doc """
  Starts the WebSocket client for given ws URL. `Phoenix.Socket.Message`s
  received from the server are forwarded to the sender pid.
  """
  def connect(sender, url, headers \\ []) do
    with {:ok, socket} <- GenServer.start_link(__MODULE__, {sender}),
         {:ok, :connected} <- GenServer.call(socket, {:connect, url, headers}) do
      {:ok, socket}
    end
  end

  @doc """
  Closes the socket
  """
  def close(socket) do
    GenServer.cast(socket, :close)
  end

  @doc """
  Sends a low-level text message to the client.
  """
  def send_text(server_pid, msg) do
    GenServer.call(server_pid, {:text, msg})
  end

  @doc false
  def init({sender}) do
    state = %__MODULE__{sender: sender}

    {:ok, state}
  end

  @doc false
  def handle_call({:connect, url, headers}, from, state) do
    uri = URI.parse(url)

    http_scheme =
      case uri.scheme do
        "ws" -> :http
        "wss" -> :https
      end

    ws_scheme =
      case uri.scheme do
        "ws" -> :ws
        "wss" -> :wss
      end

    path =
      case uri.query do
        nil -> uri.path
        query -> uri.path <> "?" <> query
      end

    with {:ok, conn} <- Mint.HTTP.connect(http_scheme, uri.host, uri.port),
         {:ok, conn, ref} <- Mint.WebSocket.upgrade(ws_scheme, conn, path, headers) do
      state = %{state | conn: conn, request_ref: ref, caller: from}
      {:noreply, state}
    else
      {:error, reason} ->
        {:reply, {:error, reason}, state}

      {:error, conn, reason} ->
        {:reply, {:error, reason}, put_in(state.conn, conn)}
    end
  end

  @doc false
  def handle_info(message, state) do
    case Mint.WebSocket.stream(state.conn, message) do
      {:ok, conn, responses} ->
        state = put_in(state.conn, conn) |> handle_responses(responses)
        if state.closing?, do: do_close(state), else: {:noreply, state}

      {:error, conn, reason, _responses} ->
        state = put_in(state.conn, conn) |> reply({:error, reason})
        {:noreply, state}

      :unknown ->
        {:noreply, state}
    end
  end

  defp do_close(state) do
    # Streaming a close frame may fail if the server has already closed
    # for writing.
    _ = stream_frame(state, :close)
    Mint.HTTP.close(state.conn)
    {:stop, :normal, state}
  end

  defp handle_responses(state, responses)

  defp handle_responses(%{request_ref: ref} = state, [{:status, ref, status} | rest]) do
    put_in(state.status, status)
    |> handle_responses(rest)
  end

  defp handle_responses(%{request_ref: ref} = state, [{:headers, ref, resp_headers} | rest]) do
    put_in(state.resp_headers, resp_headers)
    |> handle_responses(rest)
  end

  defp handle_responses(%{request_ref: ref} = state, [{:done, ref} | rest]) do
    case Mint.WebSocket.new(state.conn, ref, state.status, state.resp_headers) do
      {:ok, conn, websocket} ->
        %{state | conn: conn, websocket: websocket, status: nil, resp_headers: nil}
        |> reply({:ok, :connected})
        |> handle_responses(rest)

      {:error, conn, reason} ->
        put_in(state.conn, conn)
        |> reply({:error, reason})
    end
  end

  defp handle_responses(%{request_ref: ref, websocket: websocket} = state, [
         {:data, ref, data} | rest
       ])
       when websocket != nil do
    case Mint.WebSocket.decode(websocket, data) do
      {:ok, websocket, frames} ->
        put_in(state.websocket, websocket)
        |> handle_frames(frames)
        |> handle_responses(rest)

      {:error, websocket, reason} ->
        put_in(state.websocket, websocket)
        |> reply({:error, reason})
    end
  end

  defp handle_responses(state, [_response | rest]) do
    handle_responses(state, rest)
  end

  defp handle_responses(state, []), do: state

  defp handle_frames(state, frames) do
    {frames, state} =
      Enum.flat_map_reduce(frames, state, fn
        # prepare to close the connection when a close frame is received
        {:close, _code, _data}, state ->
          {[], put_in(state.closing?, true)}

        frame, state ->
          {[frame], state}
      end)

    Enum.each(frames, &Kernel.send(state.sender, &1))

    state
  end

  defp reply(state, response) do
    if state.caller, do: GenServer.reply(state.caller, response)
    put_in(state.caller, nil)
  end

  # Encodes a frame as a binary and sends it along the wire, keeping `conn`
  # and `websocket` up to date in `state`.
  defp stream_frame(state, frame) do
    with {:ok, websocket, data} <- Mint.WebSocket.encode(state.websocket, frame),
         state = put_in(state.websocket, websocket),
         {:ok, conn} <- Mint.WebSocket.stream_request_body(state.conn, state.request_ref, data) do
      {:ok, put_in(state.conn, conn)}
    else
      {:error, %Mint.WebSocket{} = websocket, reason} ->
        {:error, put_in(state.websocket, websocket), reason}

      {:error, conn, reason} ->
        {:error, put_in(state.conn, conn), reason}
    end
  end
end
