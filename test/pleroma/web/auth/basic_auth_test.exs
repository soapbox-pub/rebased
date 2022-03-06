# Pleroma: A lightweight social networking server
# Copyright © 2017-2022 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.Auth.BasicAuthTest do
  use Pleroma.Web.ConnCase, async: true

  import Pleroma.Factory

  test "with HTTP Basic Auth used, grants access to OAuth scope-restricted endpoints", %{
    conn: conn
  } do
    user = insert(:user)
    assert Pleroma.Password.Pbkdf2.verify_pass("test", user.password_hash)

    basic_auth_contents =
      (URI.encode_www_form(user.nickname) <> ":" <> URI.encode_www_form("test"))
      |> Base.encode64()

    # Succeeds with HTTP Basic Auth
    response =
      conn
      |> put_req_header("authorization", "Basic " <> basic_auth_contents)
      |> get("/api/v1/accounts/verify_credentials")
      |> json_response(200)

    user_nickname = user.nickname
    assert %{"username" => ^user_nickname} = response

    # Succeeds with a properly scoped OAuth token
    valid_token = insert(:oauth_token, scopes: ["read:accounts"])

    conn
    |> put_req_header("authorization", "Bearer #{valid_token.token}")
    |> get("/api/v1/accounts/verify_credentials")
    |> json_response(200)

    # Fails with a wrong-scoped OAuth token (proof of restriction)
    invalid_token = insert(:oauth_token, scopes: ["read:something"])

    conn
    |> put_req_header("authorization", "Bearer #{invalid_token.token}")
    |> get("/api/v1/accounts/verify_credentials")
    |> json_response(403)
  end
end
