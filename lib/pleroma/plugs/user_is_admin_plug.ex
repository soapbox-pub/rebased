defmodule Pleroma.Plugs.UserIsAdminPlug do
  import Plug.Conn
  alias Pleroma.User

  def init(options) do
    options
  end

  def call(%{assigns: %{user: %User{info: %{"is_admin" => false}}}} = conn, _) do
    conn
    |> assign(:user, nil)
  end

  def call(conn, _) do
    conn
  end
end
