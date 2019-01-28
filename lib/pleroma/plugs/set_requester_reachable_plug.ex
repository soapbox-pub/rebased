# Pleroma: A lightweight social networking server
# Copyright © 2017-2019 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.Plugs.SetRequesterReachablePlug do
  import Plug.Conn

  def init(_), do: []

  def call(%Plug.Conn{} = conn, _) do
    with [referer] <- get_req_header(conn, "referer"),
         do: Pleroma.Instances.set_reachable(referer)

    conn
  end
end
