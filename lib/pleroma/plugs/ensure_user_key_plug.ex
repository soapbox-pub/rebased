defmodule Pleroma.Plugs.EnsureUserKeyPlug do
  import Plug.Conn

  def init(opts) do
    opts
  end

  def call(%{assigns: %{user: _}} = conn, _), do: conn

  def call(conn, _) do
    conn
    |> assign(:user, nil)
  end
end
