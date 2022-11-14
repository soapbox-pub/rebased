# Pleroma: A lightweight social networking server
# Copyright © 2017-2022 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.MastodonAPI.InstanceControllerTest do
  # TODO: Should not need Cachex
  use Pleroma.Web.ConnCase

  alias Pleroma.Rule
  alias Pleroma.User
  import Pleroma.Factory

  @dir "test/instance_static_test"

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
    assert result["soapbox"]["version"] =~ "."

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

  test "get instance rules", %{conn: conn} do
    Rule.create(%{text: "Example rule"})
    Rule.create(%{text: "Second rule"})
    Rule.create(%{text: "Third rule"})

    conn = get(conn, "/api/v1/instance")

    assert result = json_response_and_validate_schema(conn, 200)

    rules = result["rules"]

    assert length(rules) == 3
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

  test "get instance contact information", %{conn: conn} do
    user = insert(:user, %{local: true})

    clear_config([:instance, :contact_username], user.nickname)

    conn = get(conn, "/api/v1/instance")

    assert result = json_response_and_validate_schema(conn, 200)

    assert result["contact_account"]["id"] == user.id
  end

  test "get instance information v2", %{conn: conn} do
    assert get(conn, "/api/v2/instance")
           |> json_response_and_validate_schema(200)
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

  describe "instance privacy policy" do
    setup do
      File.mkdir_p!(@dir)
      clear_config([:instance, :static_dir], @dir)

      on_exit(fn ->
        File.rm_rf(@dir)
      end)
    end

    test "get instance privacy policy", %{conn: conn} do
      clear_config([:instance, :privacy_policy], "/instance/privacy.html")

      content = "<h1>Privacy policy</h1><p>What information do we collect?</p>"

      File.mkdir!(@dir <> "/instance/")
      File.write!(@dir <> "/instance/privacy.html", content)

      conn = get(conn, "/api/v1/instance/privacy_policy")

      assert %{
               "content" => ^content,
               "updated_at" => _
             } = json_response_and_validate_schema(conn, 200)
    end

    test "returns 404 if privacy policy not specified", %{conn: conn} do
      clear_config([:instance, :privacy_policy], nil)

      conn = get(conn, "/api/v1/instance/privacy_policy")

      assert json_response_and_validate_schema(conn, 404)
    end

    test "returns 404 if privacy policy file does not exist", %{conn: conn} do
      clear_config([:instance, :privacy_policy], "/instance/i_do_not_exist.html")

      conn = get(conn, "/api/v1/instance/privacy_policy")

      assert json_response_and_validate_schema(conn, 404)
    end
  end
end
