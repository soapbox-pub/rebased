defmodule Pleroma.Plugs.LegacyAuthenticationPlug do
  import Plug.Conn
  alias Pleroma.User

  def init(options) do
    options
  end

  def call(%{assigns: %{user: %User{}}} = conn, _), do: conn

  def call(
        %{
          assigns: %{
            auth_user: %{password_hash: "$6$" <> _ = password_hash} = auth_user,
            auth_credentials: %{password: password}
          }
        } = conn,
        _
      ) do
    if :crypt.crypt(password, password_hash) == password_hash do
      conn
      |> assign(:user, auth_user)
    else
      conn
    end
  end

  def call(conn, _) do
    conn
  end
end
