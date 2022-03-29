# Pleroma: A lightweight social networking server
# Copyright © 2017-2022 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.NodeInfoTest do
  use Pleroma.Web.ConnCase

  import Pleroma.Factory

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
    clear_config([:instance, :max_account_fields], 10)
    clear_config([:instance, :max_remote_account_fields], 15)
    clear_config([:instance, :account_field_name_length], 255)
    clear_config([:instance, :account_field_value_length], 2048)

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
    clear_config([:instance, :safe_dm_mentions], true)

    response =
      conn
      |> get("/nodeinfo/2.1.json")
      |> json_response(:ok)

    assert "safe_dm_mentions" in response["metadata"]["features"]

    clear_config([:instance, :safe_dm_mentions], false)

    response =
      conn
      |> get("/nodeinfo/2.1.json")
      |> json_response(:ok)

    refute "safe_dm_mentions" in response["metadata"]["features"]
  end

  describe "`metadata/federation/enabled`" do
    setup do: clear_config([:instance, :federating])

    test "it shows if federation is enabled/disabled", %{conn: conn} do
      clear_config([:instance, :federating], true)

      response =
        conn
        |> get("/nodeinfo/2.1.json")
        |> json_response(:ok)

      assert response["metadata"]["federation"]["enabled"] == true

      clear_config([:instance, :federating], false)

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

  describe "Quarantined instances" do
    setup do
      clear_config([:mrf, :transparency], true)
      quarantined_instances = [{"example.com", "reason to quarantine"}]
      clear_config([:instance, :quarantined_instances], quarantined_instances)
    end

    test "shows quarantined instances data if enabled", %{conn: conn} do
      expected_config = ["example.com"]

      response =
        conn
        |> get("/nodeinfo/2.1.json")
        |> json_response(:ok)

      assert response["metadata"]["federation"]["quarantined_instances"] == expected_config
    end

    test "shows extra information in the quarantined_info field for relevant entries", %{
      conn: conn
    } do
      clear_config([:mrf, :transparency], true)

      expected_config = %{
        "quarantined_instances" => %{
          "example.com" => %{"reason" => "reason to quarantine"}
        }
      }

      response =
        conn
        |> get("/nodeinfo/2.1.json")
        |> json_response(:ok)

      assert response["metadata"]["federation"]["quarantined_instances_info"] == expected_config
    end
  end

  describe "MRF SimplePolicy" do
    setup do
      clear_config([:mrf, :policies], [Pleroma.Web.ActivityPub.MRF.SimplePolicy])
      clear_config([:mrf, :transparency], true)
    end

    test "shows MRF transparency data if enabled", %{conn: conn} do
      simple_config = %{"reject" => [{"example.com", ""}]}
      clear_config(:mrf_simple, simple_config)

      expected_config = %{"reject" => ["example.com"]}

      response =
        conn
        |> get("/nodeinfo/2.1.json")
        |> json_response(:ok)

      assert response["metadata"]["federation"]["mrf_simple"] == expected_config
    end

    test "performs exclusions from MRF transparency data if configured", %{conn: conn} do
      clear_config([:mrf, :transparency_exclusions], [
        {"other.site", "We don't want them to know"}
      ])

      simple_config = %{"reject" => [{"example.com", ""}, {"other.site", ""}]}
      clear_config(:mrf_simple, simple_config)

      expected_config = %{"reject" => ["example.com"]}

      response =
        conn
        |> get("/nodeinfo/2.1.json")
        |> json_response(:ok)

      assert response["metadata"]["federation"]["mrf_simple"] == expected_config
      assert response["metadata"]["federation"]["exclusions"] == true
    end

    test "shows extra information in the mrf_simple_info field for relevant entries", %{
      conn: conn
    } do
      simple_config = %{
        media_removal: [{"no.media", "LEEWWWDD >//<"}],
        media_nsfw: [],
        federated_timeline_removal: [{"no.ftl", ""}],
        report_removal: [],
        reject: [
          {"example.instance", "Some reason"},
          {"uwu.owo", "awoo to much"},
          {"no.reason", ""}
        ],
        followers_only: [],
        accept: [],
        avatar_removal: [],
        banner_removal: [],
        reject_deletes: [
          {"peak.me", "I want to peak at what they don't want me to see, eheh"}
        ]
      }

      clear_config(:mrf_simple, simple_config)

      clear_config([:mrf, :transparency_exclusions], [
        {"peak.me", "I don't want them to know"}
      ])

      expected_config = %{
        "media_removal" => %{
          "no.media" => %{"reason" => "LEEWWWDD >//<"}
        },
        "reject" => %{
          "example.instance" => %{"reason" => "Some reason"},
          "uwu.owo" => %{"reason" => "awoo to much"}
        }
      }

      response =
        conn
        |> get("/nodeinfo/2.1.json")
        |> json_response(:ok)

      assert response["metadata"]["federation"]["mrf_simple_info"] == expected_config
    end
  end
end
