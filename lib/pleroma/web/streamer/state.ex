# Pleroma: A lightweight social networking server
# Copyright © 2017-2020 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.Streamer.State do
  use GenServer
  require Logger

  alias Pleroma.Web.Streamer.StreamerSocket

  @env Mix.env()

  def start_link(_) do
    GenServer.start_link(__MODULE__, %{sockets: %{}}, name: __MODULE__)
  end

  def add_socket(topic, socket) do
    GenServer.call(__MODULE__, {:add, topic, socket})
  end

  def remove_socket(topic, socket) do
    do_remove_socket(@env, topic, socket)
  end

  def get_sockets do
    %{sockets: stream_sockets} = GenServer.call(__MODULE__, :get_state)
    stream_sockets
  end

  def init(init_arg) do
    {:ok, init_arg}
  end

  def handle_call(:get_state, _from, state) do
    {:reply, state, state}
  end

  def handle_call({:add, topic, socket}, _from, %{sockets: sockets} = state) do
    internal_topic = internal_topic(topic, socket)
    stream_socket = StreamerSocket.from_socket(socket)

    sockets_for_topic =
      sockets
      |> Map.get(internal_topic, [])
      |> List.insert_at(0, stream_socket)
      |> Enum.uniq()

    state = put_in(state, [:sockets, internal_topic], sockets_for_topic)
    Logger.debug("Got new conn for #{topic}")
    {:reply, state, state}
  end

  def handle_call({:remove, topic, socket}, _from, %{sockets: sockets} = state) do
    internal_topic = internal_topic(topic, socket)
    stream_socket = StreamerSocket.from_socket(socket)

    sockets_for_topic =
      sockets
      |> Map.get(internal_topic, [])
      |> List.delete(stream_socket)

    state = Kernel.put_in(state, [:sockets, internal_topic], sockets_for_topic)
    {:reply, state, state}
  end

  defp do_remove_socket(:test, _, _) do
    :ok
  end

  defp do_remove_socket(_env, topic, socket) do
    GenServer.call(__MODULE__, {:remove, topic, socket})
  end

  defp internal_topic(topic, socket)
       when topic in ~w[user user:notification direct] do
    "#{topic}:#{socket.assigns[:user].id}"
  end

  defp internal_topic(topic, _) do
    topic
  end
end
