# Pleroma: A lightweight social networking server
# Copyright © 2017-2018 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.NodeInfoTest do
  use Pleroma.Web.ConnCase

  import Pleroma.Factory

  test "nodeinfo shows staff accounts", %{conn: conn} do
    user = insert(:user, %{local: true, info: %{is_moderator: true}})

    conn =
      conn
      |> get("/nodeinfo/2.0.json")

    assert result = json_response(conn, 200)

    assert user.ap_id in result["metadata"]["staffAccounts"]
  end

  test "returns 404 when federation is disabled", %{conn: conn} do
    instance =
      Application.get_env(:pleroma, :instance)
      |> Keyword.put(:federating, false)

    Application.put_env(:pleroma, :instance, instance)

    conn
    |> get("/.well-known/nodeinfo")
    |> json_response(404)

    conn
    |> get("/nodeinfo/2.0.json")
    |> json_response(404)

    instance =
      Application.get_env(:pleroma, :instance)
      |> Keyword.put(:federating, true)

    Application.put_env(:pleroma, :instance, instance)
  end

  test "returns 200 when federation is enabled", %{conn: conn} do
    conn
    |> get("/.well-known/nodeinfo")
    |> json_response(200)

    conn
    |> get("/nodeinfo/2.0.json")
    |> json_response(200)
  end
end
