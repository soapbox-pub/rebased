# Pleroma: A lightweight social networking server
# Copyright © 2017-2022 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.MastodonAPI.MastodonAPIControllerTest do
  use Pleroma.Web.ConnCase, async: true

  describe "empty_array/2 (stubs)" do
    test "GET /api/v1/accounts/:id/identity_proofs" do
      %{user: user, conn: conn} = oauth_access(["read:accounts"])

      assert [] ==
               conn
               |> get("/api/v1/accounts/#{user.id}/identity_proofs")
               |> json_response(200)
    end

    test "GET /api/v1/endorsements" do
      %{conn: conn} = oauth_access(["read:accounts"])

      assert [] ==
               conn
               |> get("/api/v1/endorsements")
               |> json_response(200)
    end

    test "GET /api/v1/trends", %{conn: conn} do
      assert [] ==
               conn
               |> get("/api/v1/trends")
               |> json_response(200)
    end
  end
end
