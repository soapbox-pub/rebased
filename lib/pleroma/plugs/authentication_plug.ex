defmodule Pleroma.Plugs.AuthenticationPlug do
  alias Comeonin.Pbkdf2
  import Plug.Conn
  alias Pleroma.User

  def init(options) do
    options
  end

  def call(%{assigns: %{user: %User{}}} = conn, _), do: conn

  def call(
        %{
          assigns: %{
            auth_user: %{password_hash: password_hash} = auth_user,
            auth_credentials: %{password: password}
          }
        } = conn,
        _
      ) do
    if Pbkdf2.checkpw(password, password_hash) do
      conn
      |> assign(:user, auth_user)
    else
      conn
    end
  end

  def call(
        %{
          assigns: %{
            auth_credentials: %{password: password}
          }
        } = conn,
        _
      ) do
    Pbkdf2.dummy_checkpw()
    conn
  end

  def call(conn, _), do: conn
end
