defmodule Pleroma.Plugs.AuthenticationPlug do
  alias Comeonin.Pbkdf2
  import Plug.Conn
  alias Pleroma.User

  def init(options) do
    options
  end

  def call(%{assigns: %{user: %User{}}} = conn, _), do: conn

  def call(conn, opts) do
    with {:ok, username, password} <- decode_header(conn),
         {:ok, user} <- opts[:fetcher].(username),
         saved_user_id <- get_session(conn, :user_id),
         {:ok, verified_user} <- verify(user, password, saved_user_id)
    do
      conn
      |> assign(:user, verified_user)
      |> put_session(:user_id, verified_user.id)
    else
      _ -> conn |> halt_or_continue(opts)
    end
  end

  # Short-circuit if we have a cookie with the id for the given user.
  defp verify(%{id: id} = user, _password, id) do
    {:ok, user}
  end

  defp verify(nil, _password, _user_id) do
    Pbkdf2.dummy_checkpw
    :error
  end

  defp verify(user, password, _user_id) do
    if Pbkdf2.checkpw(password, user.password_hash) do
      {:ok, user}
    else
      :error
    end
  end

  defp decode_header(conn) do
    with ["Basic " <> header] <- get_req_header(conn, "authorization"),
         {:ok, userinfo} <- Base.decode64(header),
         [username, password] <- String.split(userinfo, ":", parts: 2)
    do
      {:ok, username, password}
    end
  end

  defp halt_or_continue(conn, %{optional: true}) do
    conn |> assign(:user, nil)
  end

  defp halt_or_continue(conn, _) do
    conn
    |> put_resp_content_type("application/json")
    |> send_resp(403, Poison.encode!(%{error: "Invalid credentials."}))
    |> halt
  end
end
