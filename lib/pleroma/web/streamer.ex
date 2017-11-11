defmodule Pleroma.Web.Streamer do
  use GenServer
  require Logger
  import Plug.Conn

  def start_link do
    spawn(fn ->
      Process.sleep(1000 * 30) # 30 seconds
      GenServer.cast(__MODULE__, %{action: :ping})
    end)
    GenServer.start_link(__MODULE__, %{}, name: __MODULE__)
  end

  def add_socket(topic, socket) do
    GenServer.cast(__MODULE__, %{action: :add, socket: socket, topic: topic})
  end

  def remove_socket(topic, socket) do
    GenServer.cast(__MODULE__, %{action: :remove, socket: socket, topic: topic})
  end

  def stream(topic, item) do
    GenServer.cast(__MODULE__, %{action: :stream, topic: topic, item: item})
  end

  def handle_cast(%{action: :ping}, topics) do
    Map.values(topics)
    |> List.flatten
    |> Enum.each(fn (socket) ->
      Logger.debug("Sending keepalive ping")
      send socket.transport_pid, {:text, ""}
    end)
    spawn(fn ->
      Process.sleep(1000 * 30) # 30 seconds
      GenServer.cast(__MODULE__, %{action: :ping})
    end)
    {:noreply, topics}
  end

  def handle_cast(%{action: :stream, topic: topic, item: item}, topics) do
    Logger.debug("Trying to push to #{topic}")
    Logger.debug("Pushing item to #{topic}")
    Enum.each(topics[topic] || [], fn (socket) ->
      json = %{
        event: "update",
        payload: Pleroma.Web.MastodonAPI.StatusView.render("status.json", activity: item) |> Poison.encode!
      } |> Poison.encode!

      send socket.transport_pid, {:text, json}
    end)
    {:noreply, topics}
  end

  def handle_cast(%{action: :add, topic: topic, socket: socket}, sockets) do
    sockets_for_topic = sockets[topic] || []
    sockets_for_topic = Enum.uniq([socket | sockets_for_topic])
    sockets = Map.put(sockets, topic, sockets_for_topic)
    Logger.debug("Got new conn for #{topic}")
    IO.inspect(sockets)
    {:noreply, sockets}
  end

  def handle_cast(%{action: :remove, topic: topic, socket: socket}, sockets) do
    sockets_for_topic = sockets[topic] || []
    sockets_for_topic = List.delete(sockets_for_topic, socket)
    sockets = Map.put(sockets, topic, sockets_for_topic)
    Logger.debug("Removed conn for #{topic}")
    IO.inspect(sockets)
    {:noreply, sockets}
  end

  def handle_cast(m, state) do
    IO.inspect("Unknown: #{inspect(m)}, #{inspect(state)}")
    {:noreply, state}
  end
end
