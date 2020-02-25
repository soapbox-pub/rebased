# Pleroma: A lightweight social networking server
# Copyright © 2017-2019 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.Plugs.HTTPSecurityPlugTest do
  use Pleroma.Web.ConnCase
  alias Pleroma.Config
  alias Plug.Conn

  clear_config([:http_securiy, :enabled])
  clear_config([:http_security, :sts])
  clear_config([:http_security, :referrer_policy])

  describe "http security enabled" do
    setup do
      Config.put([:http_security, :enabled], true)
    end

    test "it sends CSP headers when enabled", %{conn: conn} do
      conn = get(conn, "/api/v1/instance")

      refute Conn.get_resp_header(conn, "x-xss-protection") == []
      refute Conn.get_resp_header(conn, "x-permitted-cross-domain-policies") == []
      refute Conn.get_resp_header(conn, "x-frame-options") == []
      refute Conn.get_resp_header(conn, "x-content-type-options") == []
      refute Conn.get_resp_header(conn, "x-download-options") == []
      refute Conn.get_resp_header(conn, "referrer-policy") == []
      refute Conn.get_resp_header(conn, "content-security-policy") == []
    end

    test "it sends STS headers when enabled", %{conn: conn} do
      Config.put([:http_security, :sts], true)

      conn = get(conn, "/api/v1/instance")

      refute Conn.get_resp_header(conn, "strict-transport-security") == []
      refute Conn.get_resp_header(conn, "expect-ct") == []
    end

    test "it does not send STS headers when disabled", %{conn: conn} do
      Config.put([:http_security, :sts], false)

      conn = get(conn, "/api/v1/instance")

      assert Conn.get_resp_header(conn, "strict-transport-security") == []
      assert Conn.get_resp_header(conn, "expect-ct") == []
    end

    test "referrer-policy header reflects configured value", %{conn: conn} do
      conn = get(conn, "/api/v1/instance")

      assert Conn.get_resp_header(conn, "referrer-policy") == ["same-origin"]

      Config.put([:http_security, :referrer_policy], "no-referrer")

      conn =
        build_conn()
        |> get("/api/v1/instance")

      assert Conn.get_resp_header(conn, "referrer-policy") == ["no-referrer"]
    end

    test "it sends `report-to` & `report-uri` CSP response headers" do
      conn =
        build_conn()
        |> get("/api/v1/instance")

      [csp] = Conn.get_resp_header(conn, "content-security-policy")

      assert csp =~ ~r|report-uri https://endpoint.com; report-to csp-endpoint;|

      [reply_to] = Conn.get_resp_header(conn, "reply-to")

      assert reply_to ==
               "{\"endpoints\":[{\"url\":\"https://endpoint.com\"}],\"group\":\"csp-endpoint\",\"max-age\":10886400}"
    end
  end

  test "it does not send CSP headers when disabled", %{conn: conn} do
    Config.put([:http_security, :enabled], false)

    conn = get(conn, "/api/v1/instance")

    assert Conn.get_resp_header(conn, "x-xss-protection") == []
    assert Conn.get_resp_header(conn, "x-permitted-cross-domain-policies") == []
    assert Conn.get_resp_header(conn, "x-frame-options") == []
    assert Conn.get_resp_header(conn, "x-content-type-options") == []
    assert Conn.get_resp_header(conn, "x-download-options") == []
    assert Conn.get_resp_header(conn, "referrer-policy") == []
    assert Conn.get_resp_header(conn, "content-security-policy") == []
  end
end
