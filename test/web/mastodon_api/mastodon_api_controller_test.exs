# Pleroma: A lightweight social networking server
# Copyright © 2017-2019 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.MastodonAPI.MastodonAPIControllerTest do
  use Pleroma.Web.ConnCase

  alias Pleroma.Notification
  alias Pleroma.Repo
  alias Pleroma.Web.CommonAPI

  import Pleroma.Factory
  import Tesla.Mock

  setup do
    mock(fn env -> apply(HttpRequestMock, :request, [env]) end)
    :ok
  end

  clear_config([:rich_media, :enabled])

  test "unimplemented follow_requests, blocks, domain blocks" do
    user = insert(:user)

    ["blocks", "domain_blocks", "follow_requests"]
    |> Enum.each(fn endpoint ->
      conn =
        build_conn()
        |> assign(:user, user)
        |> get("/api/v1/#{endpoint}")

      assert [] = json_response(conn, 200)
    end)
  end

  describe "link headers" do
    test "preserves parameters in link headers", %{conn: conn} do
      user = insert(:user)
      other_user = insert(:user)

      {:ok, activity1} =
        CommonAPI.post(other_user, %{
          "status" => "hi @#{user.nickname}",
          "visibility" => "public"
        })

      {:ok, activity2} =
        CommonAPI.post(other_user, %{
          "status" => "hi @#{user.nickname}",
          "visibility" => "public"
        })

      notification1 = Repo.get_by(Notification, activity_id: activity1.id)
      notification2 = Repo.get_by(Notification, activity_id: activity2.id)

      conn =
        conn
        |> assign(:user, user)
        |> get("/api/v1/notifications", %{media_only: true})

      assert [link_header] = get_resp_header(conn, "link")
      assert link_header =~ ~r/media_only=true/
      assert link_header =~ ~r/min_id=#{notification2.id}/
      assert link_header =~ ~r/max_id=#{notification1.id}/
    end
  end

  describe "empty_array, stubs for mastodon api" do
    test "GET /api/v1/accounts/:id/identity_proofs", %{conn: conn} do
      user = insert(:user)

      res =
        conn
        |> assign(:user, user)
        |> get("/api/v1/accounts/#{user.id}/identity_proofs")
        |> json_response(200)

      assert res == []
    end

    test "GET /api/v1/endorsements", %{conn: conn} do
      user = insert(:user)

      res =
        conn
        |> assign(:user, user)
        |> get("/api/v1/endorsements")
        |> json_response(200)

      assert res == []
    end

    test "GET /api/v1/trends", %{conn: conn} do
      user = insert(:user)

      res =
        conn
        |> assign(:user, user)
        |> get("/api/v1/trends")
        |> json_response(200)

      assert res == []
    end
  end
end
