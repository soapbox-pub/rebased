# Pleroma: A lightweight social networking server
# Copyright © 2017-2019 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.Plugs.HTTPSignaturePlugTest do
  use Pleroma.Web.ConnCase
  alias Pleroma.Web.Plugs.HTTPSignaturePlug

  import Plug.Conn
  import Phoenix.Controller, only: [put_format: 2]
  import Mock

  test "it call HTTPSignatures to check validity if the actor sighed it" do
    params = %{"actor" => "http://mastodon.example.org/users/admin"}
    conn = build_conn(:get, "/doesntmattter", params)

    with_mock HTTPSignatures, validate_conn: fn _ -> true end do
      conn =
        conn
        |> put_req_header(
          "signature",
          "keyId=\"http://mastodon.example.org/users/admin#main-key"
        )
        |> put_format("activity+json")
        |> HTTPSignaturePlug.call(%{})

      assert conn.assigns.valid_signature == true
      assert conn.halted == false
      assert called(HTTPSignatures.validate_conn(:_))
    end
  end

  describe "requires a signature when `authorized_fetch_mode` is enabled" do
    setup do
      Pleroma.Config.put([:activitypub, :authorized_fetch_mode], true)

      on_exit(fn ->
        Pleroma.Config.put([:activitypub, :authorized_fetch_mode], false)
      end)

      params = %{"actor" => "http://mastodon.example.org/users/admin"}
      conn = build_conn(:get, "/doesntmattter", params) |> put_format("activity+json")

      [conn: conn]
    end

    test "when signature header is present", %{conn: conn} do
      with_mock HTTPSignatures, validate_conn: fn _ -> false end do
        conn =
          conn
          |> put_req_header(
            "signature",
            "keyId=\"http://mastodon.example.org/users/admin#main-key"
          )
          |> HTTPSignaturePlug.call(%{})

        assert conn.assigns.valid_signature == false
        assert conn.halted == true
        assert conn.status == 401
        assert conn.state == :sent
        assert conn.resp_body == "Request not signed"
        assert called(HTTPSignatures.validate_conn(:_))
      end

      with_mock HTTPSignatures, validate_conn: fn _ -> true end do
        conn =
          conn
          |> put_req_header(
            "signature",
            "keyId=\"http://mastodon.example.org/users/admin#main-key"
          )
          |> HTTPSignaturePlug.call(%{})

        assert conn.assigns.valid_signature == true
        assert conn.halted == false
        assert called(HTTPSignatures.validate_conn(:_))
      end
    end

    test "halts the connection when `signature` header is not present", %{conn: conn} do
      conn = HTTPSignaturePlug.call(conn, %{})
      assert conn.assigns[:valid_signature] == nil
      assert conn.halted == true
      assert conn.status == 401
      assert conn.state == :sent
      assert conn.resp_body == "Request not signed"
    end
  end
end
