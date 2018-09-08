defmodule Pleroma.Plugs.SetUserSessionIdPlug do
  import Plug.Conn
  alias Pleroma.User

  def init(opts) do
    opts
  end

  def call(%{assigns: %{user: %User{id: id}}} = conn, _) do
    conn
    |> put_session(:user_id, id)
  end

  def call(conn, _), do: conn
end
