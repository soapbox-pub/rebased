defmodule Pleroma.Plugs.UserIsAdminPlug do
  import Plug.Conn
  alias Pleroma.User

  def init(options) do
    options
  end

  def call(%{assigns: %{user: %User{info: %{is_admin: true}}}} = conn, _) do
    conn
  end

  def call(conn, _) do
    conn
    |> put_resp_content_type("application/json")
    |> send_resp(403, Jason.encode!(%{error: "User is not admin."}))
    |> halt
  end
end
