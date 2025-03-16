# Pleroma: A lightweight social networking server
# Copyright © 2017-2022 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.MastodonAPI.FollowRequestControllerTest do
  use Pleroma.Web.ConnCase, async: true

  alias Pleroma.User
  alias Pleroma.Web.CommonAPI

  import Pleroma.Factory

  defp extract_next_link_header(header) do
    [_, next_link] = Regex.run(~r{<(?<next_link>.*)>; rel="next"}, header)
    next_link
  end

  describe "locked accounts" do
    setup do
      user = insert(:user, is_locked: true)
      %{conn: conn} = oauth_access(["follow"], user: user)
      %{user: user, conn: conn}
    end

    test "/api/v1/follow_requests works", %{user: user, conn: conn} do
      other_user = insert(:user)

      {:ok, _, _, _activity} = CommonAPI.follow(user, other_user)
      {:ok, other_user, user} = User.follow(other_user, user, :follow_pending)

      assert User.following?(other_user, user) == false

      conn = get(conn, "/api/v1/follow_requests")

      assert [relationship] = json_response_and_validate_schema(conn, 200)
      assert to_string(other_user.id) == relationship["id"]
    end

    test "/api/v1/follow_requests paginates", %{user: user, conn: conn} do
      for _ <- 1..21 do
        other_user = insert(:user)
        {:ok, _, _, _activity} = CommonAPI.follow(other_user, user)
        {:ok, _, _} = User.follow(other_user, user, :follow_pending)
      end

      conn = get(conn, "/api/v1/follow_requests")
      assert length(json_response_and_validate_schema(conn, 200)) == 20
      assert [link_header] = get_resp_header(conn, "link")
      assert link_header =~ "rel=\"next\""
      next_link = extract_next_link_header(link_header)
      assert next_link =~ "/api/v1/follow_requests"
      conn = get(conn, next_link)
      assert length(json_response_and_validate_schema(conn, 200)) == 1
    end

    test "/api/v1/follow_requests/:id/authorize works", %{user: user, conn: conn} do
      other_user = insert(:user)

      {:ok, _, _, _activity} = CommonAPI.follow(user, other_user)
      {:ok, other_user, user} = User.follow(other_user, user, :follow_pending)

      user = User.get_cached_by_id(user.id)
      other_user = User.get_cached_by_id(other_user.id)

      assert User.following?(other_user, user) == false

      conn = post(conn, "/api/v1/follow_requests/#{other_user.id}/authorize")

      assert relationship = json_response_and_validate_schema(conn, 200)
      assert to_string(other_user.id) == relationship["id"]

      user = User.get_cached_by_id(user.id)
      other_user = User.get_cached_by_id(other_user.id)

      assert User.following?(other_user, user) == true
    end

    test "/api/v1/follow_requests/:id/reject works", %{user: user, conn: conn} do
      other_user = insert(:user)

      {:ok, _, _, _activity} = CommonAPI.follow(user, other_user)

      user = User.get_cached_by_id(user.id)

      conn = post(conn, "/api/v1/follow_requests/#{other_user.id}/reject")

      assert relationship = json_response_and_validate_schema(conn, 200)
      assert to_string(other_user.id) == relationship["id"]

      user = User.get_cached_by_id(user.id)
      other_user = User.get_cached_by_id(other_user.id)

      assert User.following?(other_user, user) == false
    end
  end
end
