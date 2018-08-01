defmodule Pleroma.Web.Plugs.DigestPlug do
  alias Plug.Conn
  require Logger

  def read_body(conn, opts) do
    {:ok, body, conn} = Conn.read_body(conn, opts)
    digest = "SHA-256=" <> (:crypto.hash(:sha256, body) |> Base.encode64())
    {:ok, body, Conn.assign(conn, :digest, digest)}
  end
end
