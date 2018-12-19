defmodule Pleroma.Plugs.AdminSecretAuthenticationPlug do
  import Plug.Conn
  alias Pleroma.User

  def init(options) do
    options
  end

  def secret_token do
    Pleroma.Config.get(:admin_token)
  end

  def call(%{assigns: %{user: %User{}}} = conn, _), do: conn

  def call(%{params: %{"admin_token" => admin_token}} = conn, _) do
    if secret_token() && admin_token == secret_token() do
      conn
      |> assign(:user, %User{info: %{is_admin: true}})
    else
      conn
    end
  end

  def call(conn, _), do: conn
end
