# Pleroma: A lightweight social networking server
# Copyright © 2017-2019 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.CacheControlTest do
  use Pleroma.Web.ConnCase
  alias Plug.Conn

  test "Verify Cache-Control header on static assets", %{conn: conn} do
    conn = get(conn, "/index.html")

    assert Conn.get_resp_header(conn, "cache-control") == ["public, no-cache"]
  end

  test "Verify Cache-Control header on the API", %{conn: conn} do
    conn = get(conn, "/api/v1/instance")

    assert Conn.get_resp_header(conn, "cache-control") == ["max-age=0, private, must-revalidate"]
  end
end
