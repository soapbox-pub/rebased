defmodule Pleroma.Plugs.EnsureAuthenticatedPlug do
  import Plug.Conn
  alias Pleroma.User

  def init(options) do
    options
  end

  def call(%{assigns: %{user: %User{}}} = conn, _) do
    conn
  end

  def call(conn, _) do
    conn
    |> put_resp_content_type("application/json")
    |> send_resp(403, Jason.encode!(%{error: "Invalid credentials."}))
    |> halt
  end
end
