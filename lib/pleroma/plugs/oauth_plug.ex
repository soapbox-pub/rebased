defmodule Pleroma.Plugs.OAuthPlug do
  import Plug.Conn
  import Ecto.Query

  alias Pleroma.{
    User,
    Repo,
    Web.OAuth.Token
  }

  @realm_reg Regex.compile!("Bearer\:?\s+(.*)$", "i")

  def init(options), do: options

  def call(%{assigns: %{user: %User{}}} = conn, _), do: conn

  def call(conn, _) do
    with {:ok, token} <- fetch_token(conn),
         {:ok, user} <- fetch_user(token) do
      assign(conn, :user, user)
    else
      _ -> conn
    end
  end

  # Gets user by token
  #
  @spec fetch_user(String.t()) :: {:ok, User.t()} | nil
  defp fetch_user(token) do
    query = from(q in Token, where: q.token == ^token, preload: [:user])

    with %Token{user: %{info: %{deactivated: false} = _} = user} <- Repo.one(query) do
      {:ok, user}
    end
  end

  # Gets token from session by :oauth_token key
  #
  @spec fetch_token_from_session(Plug.Conn.t()) :: :no_token_found | {:ok, String.t()}
  defp fetch_token_from_session(conn) do
    case get_session(conn, :oauth_token) do
      nil -> :no_token_found
      token -> {:ok, token}
    end
  end

  # Gets token from headers
  #
  @spec fetch_token(Plug.Conn.t()) :: :no_token_found | {:ok, String.t()}
  defp fetch_token(%Plug.Conn{} = conn) do
    headers = get_req_header(conn, "authorization")

    with :no_token_found <- fetch_token(headers),
         do: fetch_token_from_session(conn)
  end

  @spec fetch_token(Keyword.t()) :: :no_token_found | {:ok, String.t()}
  defp fetch_token([]), do: :no_token_found

  defp fetch_token([token | tail]) do
    trimmed_token = String.trim(token)

    case Regex.run(@realm_reg, trimmed_token) do
      [_, match] -> {:ok, String.trim(match)}
      _ -> fetch_token(tail)
    end
  end
end
