defmodule Pleroma.Web.Plugs.HTTPSecurityPlugTest do
  use Pleroma.Web.ConnCase
  alias Pleroma.Config
  alias Plug.Conn

  test "it sends CSP headers when enabled", %{conn: conn} do
    Config.put([:http_security, :enabled], true)

    conn =
      conn
      |> get("/api/v1/instance")

    refute Conn.get_resp_header(conn, "x-xss-protection") == []
    refute Conn.get_resp_header(conn, "x-permitted-cross-domain-policies") == []
    refute Conn.get_resp_header(conn, "x-frame-options") == []
    refute Conn.get_resp_header(conn, "x-content-type-options") == []
    refute Conn.get_resp_header(conn, "x-download-options") == []
    refute Conn.get_resp_header(conn, "referrer-policy") == []
    refute Conn.get_resp_header(conn, "content-security-policy") == []
  end

  test "it does not send CSP headers when disabled", %{conn: conn} do
    Config.put([:http_security, :enabled], false)

    conn =
      conn
      |> get("/api/v1/instance")

    assert Conn.get_resp_header(conn, "x-xss-protection") == []
    assert Conn.get_resp_header(conn, "x-permitted-cross-domain-policies") == []
    assert Conn.get_resp_header(conn, "x-frame-options") == []
    assert Conn.get_resp_header(conn, "x-content-type-options") == []
    assert Conn.get_resp_header(conn, "x-download-options") == []
    assert Conn.get_resp_header(conn, "referrer-policy") == []
    assert Conn.get_resp_header(conn, "content-security-policy") == []
  end

  test "it sends STS headers when enabled", %{conn: conn} do
    Config.put([:http_security, :enabled], true)
    Config.put([:http_security, :sts], true)

    conn =
      conn
      |> get("/api/v1/instance")

    refute Conn.get_resp_header(conn, "strict-transport-security") == []
    refute Conn.get_resp_header(conn, "expect-ct") == []
  end

  test "it does not send STS headers when disabled", %{conn: conn} do
    Config.put([:http_security, :enabled], true)
    Config.put([:http_security, :sts], false)

    conn =
      conn
      |> get("/api/v1/instance")

    assert Conn.get_resp_header(conn, "strict-transport-security") == []
    assert Conn.get_resp_header(conn, "expect-ct") == []
  end
end
