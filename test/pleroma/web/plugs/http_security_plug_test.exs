# Pleroma: A lightweight social networking server
# Copyright © 2017-2021 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.Plugs.HTTPSecurityPlugTest do
  use Pleroma.Web.ConnCase

  alias Plug.Conn

  describe "http security enabled" do
    setup do: clear_config([:http_security, :enabled], true)

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
      clear_config([:http_security, :sts], true)

      conn = get(conn, "/api/v1/instance")

      refute Conn.get_resp_header(conn, "strict-transport-security") == []
      refute Conn.get_resp_header(conn, "expect-ct") == []
    end

    test "it does not send STS headers when disabled", %{conn: conn} do
      clear_config([:http_security, :sts], false)

      conn = get(conn, "/api/v1/instance")

      assert Conn.get_resp_header(conn, "strict-transport-security") == []
      assert Conn.get_resp_header(conn, "expect-ct") == []
    end

    test "referrer-policy header reflects configured value", %{conn: conn} do
      resp = get(conn, "/api/v1/instance")

      assert Conn.get_resp_header(resp, "referrer-policy") == ["same-origin"]

      clear_config([:http_security, :referrer_policy], "no-referrer")

      resp = get(conn, "/api/v1/instance")

      assert Conn.get_resp_header(resp, "referrer-policy") == ["no-referrer"]
    end

    test "it sends `report-to` & `report-uri` CSP response headers", %{conn: conn} do
      conn = get(conn, "/api/v1/instance")

      [csp] = Conn.get_resp_header(conn, "content-security-policy")

      assert csp =~ ~r|report-uri https://endpoint.com;report-to csp-endpoint;|

      [reply_to] = Conn.get_resp_header(conn, "reply-to")

      assert reply_to ==
               "{\"endpoints\":[{\"url\":\"https://endpoint.com\"}],\"group\":\"csp-endpoint\",\"max-age\":10886400}"
    end

    test "default values for img-src and media-src with disabled media proxy", %{conn: conn} do
      conn = get(conn, "/api/v1/instance")

      [csp] = Conn.get_resp_header(conn, "content-security-policy")
      assert csp =~ "media-src 'self' https:;"
      assert csp =~ "img-src 'self' data: blob: https:;"
    end

    test "it sets the Service-Worker-Allowed header", %{conn: conn} do
      clear_config([:http_security, :enabled], true)
      clear_config([:frontends, :primary], %{"name" => "fedi-fe", "ref" => "develop"})

      clear_config([:frontends, :available], %{
        "fedi-fe" => %{
          "name" => "fedi-fe",
          "custom-http-headers" => [{"service-worker-allowed", "/"}]
        }
      })

      conn = get(conn, "/api/v1/instance")
      assert Conn.get_resp_header(conn, "service-worker-allowed") == ["/"]
    end
  end

  describe "img-src and media-src" do
    setup do
      clear_config([:http_security, :enabled], true)
      clear_config([:media_proxy, :enabled], true)
      clear_config([:media_proxy, :proxy_opts, :redirect_on_failure], false)
    end

    test "media_proxy with base_url", %{conn: conn} do
      url = "https://example.com"
      clear_config([:media_proxy, :base_url], url)
      assert_media_img_src(conn, url)
    end

    test "upload with base url", %{conn: conn} do
      url = "https://example2.com"
      clear_config([Pleroma.Upload, :base_url], url)
      assert_media_img_src(conn, url)
    end

    test "with S3 public endpoint", %{conn: conn} do
      url = "https://example3.com"
      clear_config([Pleroma.Uploaders.S3, :public_endpoint], url)
      assert_media_img_src(conn, url)
    end

    test "with captcha endpoint", %{conn: conn} do
      clear_config([Pleroma.Captcha.Mock, :endpoint], "https://captcha.com")
      assert_media_img_src(conn, "https://captcha.com")
    end

    test "with media_proxy whitelist", %{conn: conn} do
      clear_config([:media_proxy, :whitelist], ["https://example6.com", "https://example7.com"])
      assert_media_img_src(conn, "https://example7.com https://example6.com")
    end

    # TODO: delete after removing support bare domains for media proxy whitelist
    test "with media_proxy bare domains whitelist (deprecated)", %{conn: conn} do
      clear_config([:media_proxy, :whitelist], ["example4.com", "example5.com"])
      assert_media_img_src(conn, "example5.com example4.com")
    end
  end

  defp assert_media_img_src(conn, url) do
    conn = get(conn, "/api/v1/instance")
    [csp] = Conn.get_resp_header(conn, "content-security-policy")
    assert csp =~ "media-src 'self' #{url};"
    assert csp =~ "img-src 'self' data: blob: #{url};"
  end

  test "it does not send CSP headers when disabled", %{conn: conn} do
    clear_config([:http_security, :enabled], false)

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
