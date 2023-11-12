# Pleroma: A lightweight social networking server
# Copyright © 2017-2022 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.MastodonAPI.InstanceControllerTest do
  # TODO: Should not need Cachex
  use Pleroma.Web.ConnCase

  alias Pleroma.User
  import Pleroma.Factory

  test "get instance information", %{conn: conn} do
    conn = get(conn, "/api/v1/instance")
    assert result = json_response_and_validate_schema(conn, 200)

    email = Pleroma.Config.get([:instance, :email])
    thumbnail = Pleroma.Web.Endpoint.url() <> Pleroma.Config.get([:instance, :instance_thumbnail])
    background = Pleroma.Web.Endpoint.url() <> Pleroma.Config.get([:instance, :background_image])

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
             "shout_limit" => _,
             "description_limit" => _
           } = result

    assert result["pleroma"]["metadata"]["account_activation_required"] != nil
    assert result["pleroma"]["metadata"]["features"]
    assert result["pleroma"]["metadata"]["federation"]
    assert result["pleroma"]["metadata"]["fields_limits"]
    assert result["pleroma"]["vapid_public_key"]
    assert result["pleroma"]["stats"]["mau"] == 0

    assert email == from_config_email
    assert thumbnail == from_config_thumbnail
    assert background == from_config_background
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
end
