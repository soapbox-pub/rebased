defmodule Pleroma.Web.MastodonAPI.MastodonSocket do
  use Phoenix.Socket

  transport :streaming, Phoenix.Transports.WebSocket.Raw,
    timeout: :infinity # We never receive data.

  def connect(params, socket) do
    if params["stream"] == "public" do
      socket = socket
      |> assign(:topic, params["stream"])
      Pleroma.Web.Streamer.add_socket(params["stream"], socket)
      {:ok, socket}
    else
      :error
    end
  end

  def id(socket), do: nil

  def handle(:text, message, state) do
    IO.inspect message
    #| :ok
    #| state
    #| {:text, message}
    #| {:text, message, state}
    #| {:close, "Goodbye!"}
    {:text, message}
  end

  def handle(:closed, reason, %{socket: socket}) do
    topic = socket.assigns[:topic]
    Pleroma.Web.Streamer.remove_socket(topic, socket)
  end
end
