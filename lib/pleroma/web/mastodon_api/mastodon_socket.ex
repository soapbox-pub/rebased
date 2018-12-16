defmodule Pleroma.Web.MastodonAPI.MastodonSocket do
  use Phoenix.Socket

  alias Pleroma.Web.OAuth.Token
  alias Pleroma.{User, Repo}

  @spec connect(params :: map(), Phoenix.Socket.t()) :: {:ok, Phoenix.Socket.t()} | :error
  def connect(%{"access_token" => token} = params, socket) do
    with %Token{user_id: user_id} <- Repo.get_by(Token, token: token),
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
      topic =
        case stream do
          "hashtag" -> "hashtag:#{params["tag"]}"
          "list" -> "list:#{params["list"]}"
          _ -> stream
        end

      socket =
        socket
        |> assign(:topic, topic)
        |> assign(:user, user)

      Pleroma.Web.Streamer.add_socket(topic, socket)
      {:ok, socket}
    else
      _e -> :error
    end
  end

  def connect(%{"stream" => stream} = params, socket)
      when stream in ["public", "public:local", "hashtag"] do
    topic =
      case stream do
        "hashtag" -> "hashtag:#{params["tag"]}"
        _ -> stream
      end

    socket =
      socket
      |> assign(:topic, topic)

    Pleroma.Web.Streamer.add_socket(topic, socket)
    {:ok, socket}
  end

  def connect(_params, _socket), do: :error

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
