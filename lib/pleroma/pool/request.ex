# Pleroma: A lightweight social networking server
# Copyright © 2017-2020 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Pool.Request do
  use GenServer

  require Logger

  def start_link(args) do
    GenServer.start_link(__MODULE__, args)
  end

  @impl true
  def init(_), do: {:ok, []}

  @spec execute(pid() | atom(), Tesla.Client.t(), keyword(), pos_integer()) ::
          {:ok, Tesla.Env.t()} | {:error, any()}
  def execute(pid, client, request, timeout) do
    GenServer.call(pid, {:execute, client, request}, timeout)
  end

  @impl true
  def handle_call({:execute, client, request}, _from, state) do
    response = Pleroma.HTTP.request_try(client, request)

    {:reply, response, state}
  end

  @impl true
  def handle_info({:gun_data, _conn, stream, _, _}, state) do
    # in some cases if we reuse conn and got {:error, :body_too_large}
    # gun continues to send messages to this process,
    # so we flush messages for this request
    :ok = :gun.flush(stream)

    {:noreply, state}
  end

  @impl true
  def handle_info({:gun_up, _conn, _protocol}, state) do
    {:noreply, state}
  end

  @impl true
  def handle_info({:gun_down, _conn, _protocol, _reason, _killed}, state) do
    # don't flush messages here, because gun can reconnect
    {:noreply, state}
  end

  @impl true
  def handle_info({:gun_error, _conn, stream, _error}, state) do
    :ok = :gun.flush(stream)
    {:noreply, state}
  end

  @impl true
  def handle_info({:gun_push, _conn, _stream, _new_stream, _method, _uri, _headers}, state) do
    {:noreply, state}
  end

  @impl true
  def handle_info({:gun_response, _conn, _stream, _, _status, _headers}, state) do
    {:noreply, state}
  end

  @impl true
  def handle_info(msg, state) do
    Logger.warn("Received unexpected message #{inspect(__MODULE__)} #{inspect(msg)}")
    {:noreply, state}
  end
end
