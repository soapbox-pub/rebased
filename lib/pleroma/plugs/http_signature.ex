defmodule Pleroma.Web.Plugs.HTTPSignaturePlug do
  alias Pleroma.Web.HTTPSignatures
  import Plug.Conn
  require Logger

  def init(options) do
    options
  end

  def call(%{assigns: %{valid_signature: true}} = conn, opts) do
    conn
  end

  def call(conn, opts) do
    user = conn.params["actor"]
    Logger.debug("Checking sig for #{user}")
    if get_req_header(conn, "signature") do
      conn = conn
      |> put_req_header("(request-target)", String.downcase("#{conn.method} #{conn.request_path}"))

      assign(conn, :valid_signature, HTTPSignatures.validate_conn(conn))
    else
      Logger.debug("No signature header!")
      conn
    end
  end
end
