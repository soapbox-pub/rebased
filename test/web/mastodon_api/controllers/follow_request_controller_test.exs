# Pleroma: A lightweight social networking server
# Copyright © 2017-2019 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.MastodonAPI.FollowRequestControllerTest do
  use Pleroma.Web.ConnCase

  alias Pleroma.User
  alias Pleroma.Web.ActivityPub.ActivityPub

  import Pleroma.Factory

  describe "locked accounts" do
    test "/api/v1/follow_requests works" do
      user = insert(:user, locked: true)
      other_user = insert(:user)

      {:ok, _activity} = ActivityPub.follow(other_user, user)
      {:ok, other_user} = User.follow(other_user, user, "pending")

      assert User.following?(other_user, user) == false

      conn =
        build_conn()
        |> assign(:user, user)
        |> get("/api/v1/follow_requests")

      assert [relationship] = json_response(conn, 200)
      assert to_string(other_user.id) == relationship["id"]
    end

    test "/api/v1/follow_requests/:id/authorize works" do
      user = insert(:user, locked: true)
      other_user = insert(:user)

      {:ok, _activity} = ActivityPub.follow(other_user, user)
      {:ok, other_user} = User.follow(other_user, user, "pending")

      user = User.get_cached_by_id(user.id)
      other_user = User.get_cached_by_id(other_user.id)

      assert User.following?(other_user, user) == false

      conn =
        build_conn()
        |> assign(:user, user)
        |> post("/api/v1/follow_requests/#{other_user.id}/authorize")

      assert relationship = json_response(conn, 200)
      assert to_string(other_user.id) == relationship["id"]

      user = User.get_cached_by_id(user.id)
      other_user = User.get_cached_by_id(other_user.id)

      assert User.following?(other_user, user) == true
    end

    test "/api/v1/follow_requests/:id/reject works" do
      user = insert(:user, locked: true)
      other_user = insert(:user)

      {:ok, _activity} = ActivityPub.follow(other_user, user)

      user = User.get_cached_by_id(user.id)

      conn =
        build_conn()
        |> assign(:user, user)
        |> post("/api/v1/follow_requests/#{other_user.id}/reject")

      assert relationship = json_response(conn, 200)
      assert to_string(other_user.id) == relationship["id"]

      user = User.get_cached_by_id(user.id)
      other_user = User.get_cached_by_id(other_user.id)

      assert User.following?(other_user, user) == false
    end
  end
end
