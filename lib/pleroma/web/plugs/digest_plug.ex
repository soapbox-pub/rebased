# Pleroma: A lightweight social networking server
# Copyright © 2017-2020 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.Plugs.DigestPlug do
  alias Plug.Conn
  require Logger

  def read_body(conn, opts) do
    {:ok, body, conn} = Conn.read_body(conn, opts)
    digest = "SHA-256=" <> (:crypto.hash(:sha256, body) |> Base.encode64())
    {:ok, body, Conn.assign(conn, :digest, digest)}
  end
end
