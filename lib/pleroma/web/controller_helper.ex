# Pleroma: A lightweight social networking server
# Copyright © 2017-2019 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.ControllerHelper do
  use Pleroma.Web, :controller

  def json_response(conn, status, json) do
    conn
    |> put_status(status)
    |> json(json)
  end

  def set_requester_reachable(conn) do
    with [referer] <- get_req_header(conn, "referer"),
         do: Pleroma.Instances.set_reachable(referer)
  end
end
