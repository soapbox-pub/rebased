# Pleroma: A lightweight social networking server
# Copyright © 2017-2019 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.NodeInfoTest do
  use Pleroma.Web.ConnCase

  import Pleroma.Factory
  clear_config([:mrf_simple])

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
    moderator = insert(:user, local: true, is_moderator: true)
    admin = insert(:user, local: true, is_admin: true)

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

  test "returns fieldsLimits field", %{conn: conn} do
    max_account_fields = Pleroma.Config.get([:instance, :max_account_fields])
    max_remote_account_fields = Pleroma.Config.get([:instance, :max_remote_account_fields])
    account_field_name_length = Pleroma.Config.get([:instance, :account_field_name_length])
    account_field_value_length = Pleroma.Config.get([:instance, :account_field_value_length])

    Pleroma.Config.put([:instance, :max_account_fields], 10)
    Pleroma.Config.put([:instance, :max_remote_account_fields], 15)
    Pleroma.Config.put([:instance, :account_field_name_length], 255)
    Pleroma.Config.put([:instance, :account_field_value_length], 2048)

    response =
      conn
      |> get("/nodeinfo/2.1.json")
      |> json_response(:ok)

    assert response["metadata"]["fieldsLimits"]["maxFields"] == 10
    assert response["metadata"]["fieldsLimits"]["maxRemoteFields"] == 15
    assert response["metadata"]["fieldsLimits"]["nameLength"] == 255
    assert response["metadata"]["fieldsLimits"]["valueLength"] == 2048

    Pleroma.Config.put([:instance, :max_account_fields], max_account_fields)
    Pleroma.Config.put([:instance, :max_remote_account_fields], max_remote_account_fields)
    Pleroma.Config.put([:instance, :account_field_name_length], account_field_name_length)
    Pleroma.Config.put([:instance, :account_field_value_length], account_field_value_length)
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

  test "it shows if federation is enabled/disabled", %{conn: conn} do
    original = Pleroma.Config.get([:instance, :federating])

    Pleroma.Config.put([:instance, :federating], true)

    response =
      conn
      |> get("/nodeinfo/2.1.json")
      |> json_response(:ok)

    assert response["metadata"]["federation"]["enabled"] == true

    Pleroma.Config.put([:instance, :federating], false)

    response =
      conn
      |> get("/nodeinfo/2.1.json")
      |> json_response(:ok)

    assert response["metadata"]["federation"]["enabled"] == false

    Pleroma.Config.put([:instance, :federating], original)
  end

  test "it shows MRF transparency data if enabled", %{conn: conn} do
    config = Pleroma.Config.get([:instance, :rewrite_policy])
    Pleroma.Config.put([:instance, :rewrite_policy], [Pleroma.Web.ActivityPub.MRF.SimplePolicy])

    option = Pleroma.Config.get([:instance, :mrf_transparency])
    Pleroma.Config.put([:instance, :mrf_transparency], true)

    simple_config = %{"reject" => ["example.com"]}
    Pleroma.Config.put(:mrf_simple, simple_config)

    response =
      conn
      |> get("/nodeinfo/2.1.json")
      |> json_response(:ok)

    assert response["metadata"]["federation"]["mrf_simple"] == simple_config

    Pleroma.Config.put([:instance, :rewrite_policy], config)
    Pleroma.Config.put([:instance, :mrf_transparency], option)
    Pleroma.Config.put(:mrf_simple, %{})
  end

  test "it performs exclusions from MRF transparency data if configured", %{conn: conn} do
    config = Pleroma.Config.get([:instance, :rewrite_policy])
    Pleroma.Config.put([:instance, :rewrite_policy], [Pleroma.Web.ActivityPub.MRF.SimplePolicy])

    option = Pleroma.Config.get([:instance, :mrf_transparency])
    Pleroma.Config.put([:instance, :mrf_transparency], true)

    exclusions = Pleroma.Config.get([:instance, :mrf_transparency_exclusions])
    Pleroma.Config.put([:instance, :mrf_transparency_exclusions], ["other.site"])

    simple_config = %{"reject" => ["example.com", "other.site"]}
    expected_config = %{"reject" => ["example.com"]}

    Pleroma.Config.put(:mrf_simple, simple_config)

    response =
      conn
      |> get("/nodeinfo/2.1.json")
      |> json_response(:ok)

    assert response["metadata"]["federation"]["mrf_simple"] == expected_config
    assert response["metadata"]["federation"]["exclusions"] == true

    Pleroma.Config.put([:instance, :rewrite_policy], config)
    Pleroma.Config.put([:instance, :mrf_transparency], option)
    Pleroma.Config.put([:instance, :mrf_transparency_exclusions], exclusions)
    Pleroma.Config.put(:mrf_simple, %{})
  end
end
