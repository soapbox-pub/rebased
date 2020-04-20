# Pleroma: A lightweight social networking server
# Copyright © 2017-2020 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Tests.OAuthTestControllerTest do
  use Pleroma.Web.ConnCase

  import Pleroma.Factory

  setup %{conn: conn} do
    user = insert(:user)
    conn = assign(conn, :user, user)
    %{conn: conn, user: user}
  end

  test "missed_oauth", %{conn: conn} do
    res =
      conn
      |> get("/test/authenticated_api/missed_oauth")
      |> json_response(403)

    assert res ==
             %{
               "error" =>
                 "Security violation: OAuth scopes check was neither handled nor explicitly skipped."
             }
  end

  test "skipped_oauth", %{conn: conn} do
    conn
    |> assign(:token, nil)
    |> get("/test/authenticated_api/skipped_oauth")
    |> json_response(200)
  end

  test "performed_oauth", %{user: user} do
    %{conn: good_token_conn} = oauth_access(["read"], user: user)

    good_token_conn
    |> get("/test/authenticated_api/performed_oauth")
    |> json_response(200)

    %{conn: bad_token_conn} = oauth_access(["follow"], user: user)

    bad_token_conn
    |> get("/test/authenticated_api/performed_oauth")
    |> json_response(403)
  end
end
