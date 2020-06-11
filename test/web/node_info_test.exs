# Pleroma: A lightweight social networking server
# Copyright © 2017-2020 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.NodeInfoTest do
  use Pleroma.Web.ConnCase

  import Pleroma.Factory

  alias Pleroma.Config

  setup do: clear_config([:mrf_simple])
  setup do: clear_config(:instance)

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

    assert Config.get([Pleroma.User, :restricted_nicknames]) ==
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
    Config.put([:instance, :max_account_fields], 10)
    Config.put([:instance, :max_remote_account_fields], 15)
    Config.put([:instance, :account_field_name_length], 255)
    Config.put([:instance, :account_field_value_length], 2048)

    response =
      conn
      |> get("/nodeinfo/2.1.json")
      |> json_response(:ok)

    assert response["metadata"]["fieldsLimits"]["maxFields"] == 10
    assert response["metadata"]["fieldsLimits"]["maxRemoteFields"] == 15
    assert response["metadata"]["fieldsLimits"]["nameLength"] == 255
    assert response["metadata"]["fieldsLimits"]["valueLength"] == 2048
  end

  test "it returns the safe_dm_mentions feature if enabled", %{conn: conn} do
    option = Config.get([:instance, :safe_dm_mentions])
    Config.put([:instance, :safe_dm_mentions], true)

    response =
      conn
      |> get("/nodeinfo/2.1.json")
      |> json_response(:ok)

    assert "safe_dm_mentions" in response["metadata"]["features"]

    Config.put([:instance, :safe_dm_mentions], false)

    response =
      conn
      |> get("/nodeinfo/2.1.json")
      |> json_response(:ok)

    refute "safe_dm_mentions" in response["metadata"]["features"]

    Config.put([:instance, :safe_dm_mentions], option)
  end

  describe "`metadata/federation/enabled`" do
    setup do: clear_config([:instance, :federating])

    test "it shows if federation is enabled/disabled", %{conn: conn} do
      Config.put([:instance, :federating], true)

      response =
        conn
        |> get("/nodeinfo/2.1.json")
        |> json_response(:ok)

      assert response["metadata"]["federation"]["enabled"] == true

      Config.put([:instance, :federating], false)

      response =
        conn
        |> get("/nodeinfo/2.1.json")
        |> json_response(:ok)

      assert response["metadata"]["federation"]["enabled"] == false
    end
  end

  test "it shows default features flags", %{conn: conn} do
    response =
      conn
      |> get("/nodeinfo/2.1.json")
      |> json_response(:ok)

    default_features = [
      "pleroma_api",
      "mastodon_api",
      "mastodon_api_streaming",
      "polls",
      "pleroma_explicit_addressing",
      "shareable_emoji_packs",
      "multifetch",
      "pleroma_emoji_reactions",
      "pleroma:api/v1/notifications:include_types_filter",
      "pleroma_chat_messages"
    ]

    assert MapSet.subset?(
             MapSet.new(default_features),
             MapSet.new(response["metadata"]["features"])
           )
  end

  test "it shows MRF transparency data if enabled", %{conn: conn} do
    config = Config.get([:instance, :rewrite_policy])
    Config.put([:instance, :rewrite_policy], [Pleroma.Web.ActivityPub.MRF.SimplePolicy])

    option = Config.get([:instance, :mrf_transparency])
    Config.put([:instance, :mrf_transparency], true)

    simple_config = %{"reject" => ["example.com"]}
    Config.put(:mrf_simple, simple_config)

    response =
      conn
      |> get("/nodeinfo/2.1.json")
      |> json_response(:ok)

    assert response["metadata"]["federation"]["mrf_simple"] == simple_config

    Config.put([:instance, :rewrite_policy], config)
    Config.put([:instance, :mrf_transparency], option)
    Config.put(:mrf_simple, %{})
  end

  test "it performs exclusions from MRF transparency data if configured", %{conn: conn} do
    config = Config.get([:instance, :rewrite_policy])
    Config.put([:instance, :rewrite_policy], [Pleroma.Web.ActivityPub.MRF.SimplePolicy])

    option = Config.get([:instance, :mrf_transparency])
    Config.put([:instance, :mrf_transparency], true)

    exclusions = Config.get([:instance, :mrf_transparency_exclusions])
    Config.put([:instance, :mrf_transparency_exclusions], ["other.site"])

    simple_config = %{"reject" => ["example.com", "other.site"]}
    expected_config = %{"reject" => ["example.com"]}

    Config.put(:mrf_simple, simple_config)

    response =
      conn
      |> get("/nodeinfo/2.1.json")
      |> json_response(:ok)

    assert response["metadata"]["federation"]["mrf_simple"] == expected_config
    assert response["metadata"]["federation"]["exclusions"] == true

    Config.put([:instance, :rewrite_policy], config)
    Config.put([:instance, :mrf_transparency], option)
    Config.put([:instance, :mrf_transparency_exclusions], exclusions)
    Config.put(:mrf_simple, %{})
  end
end
