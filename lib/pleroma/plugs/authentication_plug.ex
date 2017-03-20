defmodule Pleroma.Plugs.AuthenticationPlug do
  import Plug.Conn

  def init(options) do
    options
  end

  def call(conn, opts) do
    with {:ok, username, password} <- decode_header(conn),
         {:ok, user} <- opts[:fetcher].(username),
         {:ok, verified_user} <- verify(user, password)
    do
      conn |> assign(:user, verified_user)
    else
      _ -> conn |> halt_or_continue(opts)
    end
  end

  defp verify(nil, _password) do
    Comeonin.Pbkdf2.dummy_checkpw
    :error
  end

  defp verify(user, password) do
    if Comeonin.Pbkdf2.checkpw(password, user[:password_hash]) do
      {:ok, user}
    else
      :error
    end
  end

  defp decode_header(conn) do
    with ["Basic " <> header] <- get_req_header(conn, "authorization"),
         {:ok, userinfo} <- Base.decode64(header),
         [username, password] <- String.split(userinfo, ":")
    do
      { :ok, username, password }
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
