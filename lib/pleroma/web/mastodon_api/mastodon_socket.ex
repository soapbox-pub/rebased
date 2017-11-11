defmodule Pleroma.Web.MastodonAPI.MastodonSocket do
  use Phoenix.Socket

  transport :streaming, Phoenix.Transports.WebSocket.Raw

  def connect(params, socket) do
    IO.inspect(params)
    Pleroma.Web.Streamer.add_socket(params["stream"], socket)
    {:ok, socket}
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

  def handle(:closed, reason, _state) do
    IO.inspect reason
  end
end
