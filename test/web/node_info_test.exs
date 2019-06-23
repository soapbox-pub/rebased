# Pleroma: A lightweight social networking server
# Copyright © 2017-2018 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.NodeInfoTest do
  use Pleroma.Web.ConnCase

  import Pleroma.Factory

  test "GET /.well-known/nodeinfo", %{conn: conn} do
    links =
      conn
      |> get("/.well-known/nodeinfo")
      |> json_response(200)
      |> Map.fetch!("links")

    Enum.each(links, fn link ->
      href = Map.fetch!(link, "href")

      conn
      |> get(href)
      |> json_response(200)
    end)
  end

  test "nodeinfo shows staff accounts", %{conn: conn} do
    moderator = insert(:user, %{local: true, info: %{is_moderator: true}})
    admin = insert(:user, %{local: true, info: %{is_admin: true}})

    conn =
      conn
      |> get("/nodeinfo/2.1.json")

    assert result = json_response(conn, 200)

    assert moderator.ap_id in result["metadata"]["staffAccounts"]
    assert admin.ap_id in result["metadata"]["staffAccounts"]
  end

  test "nodeinfo shows restricted nicknames", %{conn: conn} do
    conn =
      conn
      |> get("/nodeinfo/2.1.json")

    assert result = json_response(conn, 200)

    assert Pleroma.Config.get([Pleroma.User, :restricted_nicknames]) ==
             result["metadata"]["restrictedNicknames"]
  end

  test "returns software.repository field in nodeinfo 2.1", %{conn: conn} do
    conn
    |> get("/.well-known/nodeinfo")
    |> json_response(200)

    conn =
      conn
      |> get("/nodeinfo/2.1.json")

    assert result = json_response(conn, 200)
    assert Pleroma.Application.repository() == result["software"]["repository"]
  end

  test "it returns the safe_dm_mentions feature if enabled", %{conn: conn} do
    option = Pleroma.Config.get([:instance, :safe_dm_mentions])
    Pleroma.Config.put([:instance, :safe_dm_mentions], true)

    response =
      conn
      |> get("/nodeinfo/2.1.json")
      |> json_response(:ok)

    assert "safe_dm_mentions" in response["metadata"]["features"]

    Pleroma.Config.put([:instance, :safe_dm_mentions], false)

    response =
      conn
      |> get("/nodeinfo/2.1.json")
      |> json_response(:ok)

    refute "safe_dm_mentions" in response["metadata"]["features"]

    Pleroma.Config.put([:instance, :safe_dm_mentions], option)
  end
end
