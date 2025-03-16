# Pleroma: A lightweight social networking server
# Copyright © 2017-2024 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.PleromaAPI.FollowRequestControllerTest do
  use Pleroma.Web.ConnCase, async: true

  alias Pleroma.Web.CommonAPI

  import Pleroma.Factory

  test "/api/v1/pleroma/outgoing_follow_requests works" do
    %{conn: conn, user: user} = oauth_access(["read:follows"])

    other_user1 = insert(:user)
    other_user2 = insert(:user, is_locked: true)
    _other_user3 = insert(:user)

    {:ok, _, _, _} = CommonAPI.follow(other_user1, user)
    {:ok, _, _, _} = CommonAPI.follow(other_user2, user)

    conn = get(conn, "/api/v1/pleroma/outgoing_follow_requests")

    assert [relationship] = json_response_and_validate_schema(conn, 200)
    assert to_string(other_user2.id) == relationship["id"]
  end
end
