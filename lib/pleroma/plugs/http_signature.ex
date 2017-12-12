defmodule Pleroma.Web.Plugs.HTTPSignaturePlug do
  alias Pleroma.Web.HTTPSignatures
  import Plug.Conn

  def init(options) do
    options
  end

  def call(conn, opts) do
    if get_req_header(conn, "signature") do
      conn = conn
      |> put_req_header("(request-target)", String.downcase("#{conn.method} #{conn.request_path}"))

      assign(conn, :valid_signature, HTTPSignatures.validate_conn(conn))
    else
      conn
    end
  end
end
