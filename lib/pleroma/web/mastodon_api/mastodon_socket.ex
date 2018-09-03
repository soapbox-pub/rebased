defmodule Pleroma.Web.MastodonAPI.MastodonSocket do
  use Phoenix.Socket

  alias Pleroma.Web.OAuth.Token
  alias Pleroma.{User, Repo}

  transport(
    :streaming,
    Phoenix.Transports.WebSocket.Raw,
    # We never receive data.
    timeout: :infinity
  )

  def connect(params, socket) do
    with token when not is_nil(token) <- params["access_token"],
         %Token{user_id: user_id} <- Repo.get_by(Token, token: token),
         %User{} = user <- Repo.get(User, user_id),
         stream
         when stream in [
                "public",
                "public:local",
                "public:media",
                "public:local:media",
                "user",
                "direct",
                "list",
                "hashtag"
              ] <- params["stream"] do
      topic = if stream == "list", do: "list:#{params["list"]}", else: stream
      socket_stream = if stream == "hashtag", do: "hashtag:#{params["tag"]}", else: stream

      socket =
        socket
        |> assign(:topic, topic)
        |> assign(:user, user)

      Pleroma.Web.Streamer.add_socket(socket_stream, socket)
      {:ok, socket}
    else
      _e -> :error
    end
  end

  def id(_), do: nil

  def handle(:text, message, _state) do
    # | :ok
    # | state
    # | {:text, message}
    # | {:text, message, state}
    # | {:close, "Goodbye!"}
    {:text, message}
  end

  def handle(:closed, _, %{socket: socket}) do
    topic = socket.assigns[:topic]
    Pleroma.Web.Streamer.remove_socket(topic, socket)
  end
end
