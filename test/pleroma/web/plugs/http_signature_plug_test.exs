# Pleroma: A lightweight social networking server
# Copyright © 2017-2022 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.Plugs.HTTPSignaturePlugTest do
  use Pleroma.Web.ConnCase, async: true

  alias Pleroma.StaticStubbedConfigMock, as: ConfigMock
  alias Pleroma.StubbedHTTPSignaturesMock, as: HTTPSignaturesMock
  alias Pleroma.Web.Plugs.HTTPSignaturePlug

  import Mox
  import Phoenix.Controller, only: [put_format: 2]
  import Plug.Conn

  test "it calls HTTPSignatures to check validity if the actor signed it" do
    params = %{"actor" => "http://mastodon.example.org/users/admin"}
    conn = build_conn(:get, "/doesntmattter", params)

    HTTPSignaturesMock
    |> expect(:validate_conn, fn _ -> true end)

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
  end

  describe "requires a signature when `authorized_fetch_mode` is enabled" do
    setup do
      params = %{"actor" => "http://mastodon.example.org/users/admin"}
      conn = build_conn(:get, "/doesntmattter", params) |> put_format("activity+json")

      [conn: conn]
    end

    test "when signature header is present", %{conn: orig_conn} do
      ConfigMock
      |> expect(:get, fn [:activitypub, :authorized_fetch_mode], false -> true end)
      |> expect(:get, fn [:activitypub, :authorized_fetch_mode_exceptions], [] -> [] end)

      HTTPSignaturesMock
      |> expect(:validate_conn, 2, fn _ -> false end)

      conn =
        orig_conn
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

      ConfigMock
      |> expect(:get, fn [:activitypub, :authorized_fetch_mode], false -> true end)

      HTTPSignaturesMock
      |> expect(:validate_conn, fn _ -> true end)

      conn =
        orig_conn
        |> put_req_header(
          "signature",
          "keyId=\"http://mastodon.example.org/users/admin#main-key"
        )
        |> HTTPSignaturePlug.call(%{})

      assert conn.assigns.valid_signature == true
      assert conn.halted == false
    end

    test "halts the connection when `signature` header is not present", %{conn: conn} do
      ConfigMock
      |> expect(:get, fn [:activitypub, :authorized_fetch_mode], false -> true end)
      |> expect(:get, fn [:activitypub, :authorized_fetch_mode_exceptions], [] -> [] end)

      conn = HTTPSignaturePlug.call(conn, %{})
      assert conn.assigns[:valid_signature] == nil
      assert conn.halted == true
      assert conn.status == 401
      assert conn.state == :sent
      assert conn.resp_body == "Request not signed"
    end

    test "exempts specific IPs from `authorized_fetch_mode_exceptions`", %{conn: conn} do
      ConfigMock
      |> expect(:get, fn [:activitypub, :authorized_fetch_mode], false -> true end)
      |> expect(:get, fn [:activitypub, :authorized_fetch_mode_exceptions], [] ->
        ["192.168.0.0/24"]
      end)
      |> expect(:get, fn [:activitypub, :authorized_fetch_mode], false -> true end)

      HTTPSignaturesMock
      |> expect(:validate_conn, 2, fn _ -> false end)

      conn =
        conn
        |> Map.put(:remote_ip, {192, 168, 0, 1})
        |> put_req_header(
          "signature",
          "keyId=\"http://mastodon.example.org/users/admin#main-key"
        )
        |> HTTPSignaturePlug.call(%{})

      assert conn.remote_ip == {192, 168, 0, 1}
      assert conn.halted == false
    end
  end

  test "rejects requests from `rejected_instances` when `authorized_fetch_mode` is enabled" do
    ConfigMock
    |> expect(:get, fn [:activitypub, :authorized_fetch_mode], false -> true end)
    |> expect(:get, fn [:instance, :rejected_instances] ->
      [{"mastodon.example.org", "no reason"}]
    end)

    HTTPSignaturesMock
    |> expect(:validate_conn, fn _ -> true end)

    conn =
      build_conn(:get, "/doesntmattter", %{"actor" => "http://mastodon.example.org/users/admin"})
      |> put_req_header(
        "signature",
        "keyId=\"http://mastodon.example.org/users/admin#main-key"
      )
      |> put_format("activity+json")
      |> HTTPSignaturePlug.call(%{})

    assert conn.assigns.valid_signature == true
    assert conn.halted == true

    ConfigMock
    |> expect(:get, fn [:activitypub, :authorized_fetch_mode], false -> true end)
    |> expect(:get, fn [:instance, :rejected_instances] ->
      [{"mastodon.example.org", "no reason"}]
    end)

    HTTPSignaturesMock
    |> expect(:validate_conn, fn _ -> true end)

    conn =
      build_conn(:get, "/doesntmattter", %{"actor" => "http://allowed.example.org/users/admin"})
      |> put_req_header(
        "signature",
        "keyId=\"http://allowed.example.org/users/admin#main-key"
      )
      |> put_format("activity+json")
      |> HTTPSignaturePlug.call(%{})

    assert conn.assigns.valid_signature == true
    assert conn.halted == false
  end
end
