# Pleroma: A lightweight social networking server
# Copyright © 2017-2019 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.MastodonAPI.FollowRequestControllerTest do
  use Pleroma.Web.ConnCase

  alias Pleroma.User
  alias Pleroma.Web.ActivityPub.ActivityPub

  import Pleroma.Factory

  describe "locked accounts" do
    setup do
      user = insert(:user, locked: true)
      %{conn: conn} = oauth_access(["follow"], user: user)
      %{user: user, conn: conn}
    end

    test "/api/v1/follow_requests works", %{user: user, conn: conn} do
      other_user = insert(:user)

      {:ok, _activity} = ActivityPub.follow(other_user, user)
      {:ok, other_user} = User.follow(other_user, user, "pending")

      assert User.following?(other_user, user) == false

      conn = get(conn, "/api/v1/follow_requests")

      assert [relationship] = json_response(conn, 200)
      assert to_string(other_user.id) == relationship["id"]
    end

    test "/api/v1/follow_requests/:id/authorize works", %{user: user, conn: conn} do
      other_user = insert(:user)

      {:ok, _activity} = ActivityPub.follow(other_user, user)
      {:ok, other_user} = User.follow(other_user, user, "pending")

      user = User.get_cached_by_id(user.id)
      other_user = User.get_cached_by_id(other_user.id)

      assert User.following?(other_user, user) == false

      conn = post(conn, "/api/v1/follow_requests/#{other_user.id}/authorize")

      assert relationship = json_response(conn, 200)
      assert to_string(other_user.id) == relationship["id"]

      user = User.get_cached_by_id(user.id)
      other_user = User.get_cached_by_id(other_user.id)

      assert User.following?(other_user, user) == true
    end

    test "/api/v1/follow_requests/:id/reject works", %{user: user, conn: conn} do
      other_user = insert(:user)

      {:ok, _activity} = ActivityPub.follow(other_user, user)

      user = User.get_cached_by_id(user.id)

      conn = post(conn, "/api/v1/follow_requests/#{other_user.id}/reject")

      assert relationship = json_response(conn, 200)
      assert to_string(other_user.id) == relationship["id"]

      user = User.get_cached_by_id(user.id)
      other_user = User.get_cached_by_id(other_user.id)

      assert User.following?(other_user, user) == false
    end
  end
end
