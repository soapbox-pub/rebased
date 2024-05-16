# Pleroma: A lightweight social networking server
# Copyright © 2017-2022 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.MastodonAPI.InstanceControllerTest do
  # TODO: Should not need Cachex
  use Pleroma.Web.ConnCase

  alias Pleroma.Rule
  alias Pleroma.User
  import Pleroma.Factory

  test "get instance information", %{conn: conn} do
    clear_config([:auth, :oauth_consumer_strategies], [])

    conn = get(conn, "/api/v1/instance")
    assert result = json_response_and_validate_schema(conn, 200)

    email = Pleroma.Config.get([:instance, :email])
    thumbnail = Pleroma.Web.Endpoint.url() <> Pleroma.Config.get([:instance, :instance_thumbnail])
    background = Pleroma.Web.Endpoint.url() <> Pleroma.Config.get([:instance, :background_image])
    favicon = Pleroma.Web.Endpoint.url() <> Pleroma.Config.get([:instance, :favicon])

    # Note: not checking for "max_toot_chars" since it's optional
    assert %{
             "uri" => _,
             "title" => _,
             "description" => _,
             "short_description" => _,
             "version" => _,
             "email" => from_config_email,
             "urls" => %{
               "streaming_api" => _
             },
             "stats" => _,
             "thumbnail" => from_config_thumbnail,
             "languages" => _,
             "registrations" => _,
             "approval_required" => _,
             "poll_limits" => _,
             "upload_limit" => _,
             "avatar_upload_limit" => _,
             "background_upload_limit" => _,
             "banner_upload_limit" => _,
             "background_image" => from_config_background,
             "description_limit" => _,
             "rules" => _,
             "pleroma" => %{
               "favicon" => from_config_favicon
             }
           } = result

    assert result["version"] =~ "Pleroma"
    assert result["pleroma"]["metadata"]["account_activation_required"] != nil
    assert result["pleroma"]["metadata"]["features"]
    assert result["pleroma"]["metadata"]["federation"]
    assert result["pleroma"]["metadata"]["fields_limits"]
    assert result["pleroma"]["vapid_public_key"]
    assert result["pleroma"]["stats"]["mau"] == 0
    assert result["pleroma"]["oauth_consumer_strategies"] == []

    assert email == from_config_email
    assert thumbnail == from_config_thumbnail
    assert background == from_config_background
    assert favicon == from_config_favicon
  end

  test "get instance stats", %{conn: conn} do
    user = insert(:user, %{local: true})

    user2 = insert(:user, %{local: true})
    {:ok, _user2} = User.set_activation(user2, false)

    insert(:user, %{local: false, nickname: "u@peer1.com"})
    insert(:user, %{local: false, nickname: "u@peer2.com"})

    {:ok, _} = Pleroma.Web.CommonAPI.post(user, %{status: "cofe"})

    Pleroma.Stats.force_update()

    conn = get(conn, "/api/v1/instance")

    assert result = json_response_and_validate_schema(conn, 200)

    stats = result["stats"]

    assert stats
    assert stats["user_count"] == 1
    assert stats["status_count"] == 1
    assert stats["domain_count"] == 2
  end

  test "get peers", %{conn: conn} do
    insert(:user, %{local: false, nickname: "u@peer1.com"})
    insert(:user, %{local: false, nickname: "u@peer2.com"})

    Pleroma.Stats.force_update()

    conn = get(conn, "/api/v1/instance/peers")

    assert result = json_response_and_validate_schema(conn, 200)

    assert ["peer1.com", "peer2.com"] == Enum.sort(result)
  end

  test "get instance configuration", %{conn: conn} do
    clear_config([:instance, :limit], 476)

    conn = get(conn, "/api/v1/instance")

    assert result = json_response_and_validate_schema(conn, 200)

    assert result["configuration"]["statuses"]["max_characters"] == 476
  end

  test "get oauth_consumer_strategies", %{conn: conn} do
    clear_config([:auth, :oauth_consumer_strategies], ["keycloak"])

    conn = get(conn, "/api/v1/instance")

    assert result = json_response_and_validate_schema(conn, 200)

    assert result["pleroma"]["oauth_consumer_strategies"] == ["keycloak"]
  end

  describe "instance domain blocks" do
    setup do
      clear_config([:mrf_simple, :reject], [{"fediverse.pl", "uses Soapbox"}])
    end

    test "get instance domain blocks", %{conn: conn} do
      conn = get(conn, "/api/v1/instance/domain_blocks")

      assert [
               %{
                 "comment" => "uses Soapbox",
                 "digest" => "55e3f44aefe7eb022d3b1daaf7396cabf7f181bf6093c8ea841e30c9fc7d8226",
                 "domain" => "fediverse.pl",
                 "severity" => "suspend"
               }
             ] == json_response_and_validate_schema(conn, 200)
    end

    test "returns empty array if mrf transparency is disabled", %{conn: conn} do
      clear_config([:mrf, :transparency], false)

      conn = get(conn, "/api/v1/instance/domain_blocks")

      assert [] == json_response_and_validate_schema(conn, 200)
    end
  end

  test "instance languages", %{conn: conn} do
    assert %{"languages" => ["en"]} =
             conn
             |> get("/api/v1/instance")
             |> json_response_and_validate_schema(200)

    clear_config([:instance, :languages], ["aa", "bb"])

    assert %{"languages" => ["aa", "bb"]} =
             conn
             |> get("/api/v1/instance")
             |> json_response_and_validate_schema(200)
  end

  test "get instance contact information", %{conn: conn} do
    user = insert(:user, %{local: true})

    clear_config([:instance, :contact_username], user.nickname)

    conn = get(conn, "/api/v1/instance")

    assert result = json_response_and_validate_schema(conn, 200)

    assert result["contact_account"]["id"] == user.id
  end

  test "get instance information v2", %{conn: conn} do
    clear_config([:auth, :oauth_consumer_strategies], [])

    assert get(conn, "/api/v2/instance")
           |> json_response_and_validate_schema(200)
  end

  test "translation languages matrix", %{conn: conn} do
    clear_config([Pleroma.Language.Translation, :provider], TranslationMock)

    assert %{"en" => ["pl"], "pl" => ["en"]} =
             conn
             |> get("/api/v1/instance/translation_languages")
             |> json_response_and_validate_schema(200)
  end

  test "restrict_unauthenticated", %{conn: conn} do
    result =
      conn
      |> get("/api/v1/instance")
      |> json_response_and_validate_schema(200)

    assert result["pleroma"]["metadata"]["restrict_unauthenticated"]["timelines"]["local"] ==
             false
  end

  test "instance domains", %{conn: conn} do
    clear_config([:instance, :multitenancy], %{enabled: true})

    {:ok, %{id: domain_id}} =
      Pleroma.Domain.create(%{
        domain: "pleroma.example.org"
      })

    domain_id = to_string(domain_id)

    assert %{
             "pleroma" => %{
               "metadata" => %{
                 "multitenancy" => %{
                   "enabled" => true,
                   "domains" => [
                     %{
                       "id" => "",
                       "domain" => _,
                       "public" => true
                     },
                     %{
                       "id" => ^domain_id,
                       "domain" => "pleroma.example.org",
                       "public" => false
                     }
                   ]
                 }
               }
             }
           } =
             conn
             |> get("/api/v1/instance")
             |> json_response_and_validate_schema(200)

    clear_config([:instance, :multitenancy, :enabled], false)

    assert %{
             "pleroma" => %{
               "metadata" => %{
                 "multitenancy" => nil
               }
             }
           } =
             conn
             |> get("/api/v1/instance")
             |> json_response_and_validate_schema(200)
  end

  test "get instance rules", %{conn: conn} do
    Rule.create(%{text: "Example rule", hint: "Rule description", priority: 1})
    Rule.create(%{text: "Third rule", priority: 2})
    Rule.create(%{text: "Second rule", priority: 1})

    conn = get(conn, "/api/v1/instance")

    assert result = json_response_and_validate_schema(conn, 200)

    assert [
             %{
               "text" => "Example rule",
               "hint" => "Rule description"
             },
             %{
               "text" => "Second rule",
               "hint" => ""
             },
             %{
               "text" => "Third rule",
               "hint" => ""
             }
           ] = result["rules"]
  end
end
