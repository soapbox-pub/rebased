# Pleroma: A lightweight social networking server
# Copyright © 2017-2022 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.Plugs.HTTPSecurityPlugTest do
  use Pleroma.Web.ConnCase, async: true

  alias Plug.Conn

  import Mox

  setup do
    base_config = Pleroma.Config.get([:http_security])
    %{base_config: base_config}
  end

  defp mock_config(config, additional \\ %{}) do
    Pleroma.StaticStubbedConfigMock
    |> stub(:get, fn
      [:http_security, key] -> config[key]
      key -> additional[key]
    end)
  end

  describe "http security enabled" do
    setup %{base_config: base_config} do
      %{base_config: Keyword.put(base_config, :enabled, true)}
    end

    test "it does not contain unsafe-eval", %{conn: conn, base_config: base_config} do
      mock_config(base_config)

      conn = get(conn, "/api/v1/instance")
      [header] = Conn.get_resp_header(conn, "content-security-policy")
      refute header =~ ~r/unsafe-eval/
    end

    test "with allow_unsafe_eval set, it does contain it", %{conn: conn, base_config: base_config} do
      base_config =
        base_config
        |> Keyword.put(:allow_unsafe_eval, true)

      mock_config(base_config)

      conn = get(conn, "/api/v1/instance")
      [header] = Conn.get_resp_header(conn, "content-security-policy")
      assert header =~ ~r/unsafe-eval/
    end

    test "it sends CSP headers when enabled", %{conn: conn, base_config: base_config} do
      mock_config(base_config)
      conn = get(conn, "/api/v1/instance")

      refute Conn.get_resp_header(conn, "x-xss-protection") == []
      refute Conn.get_resp_header(conn, "x-permitted-cross-domain-policies") == []
      refute Conn.get_resp_header(conn, "x-frame-options") == []
      refute Conn.get_resp_header(conn, "x-content-type-options") == []
      refute Conn.get_resp_header(conn, "x-download-options") == []
      refute Conn.get_resp_header(conn, "referrer-policy") == []
      refute Conn.get_resp_header(conn, "content-security-policy") == []
    end

    test "it sends STS headers when enabled", %{conn: conn, base_config: base_config} do
      base_config
      |> Keyword.put(:sts, true)
      |> mock_config()

      conn = get(conn, "/api/v1/instance")

      refute Conn.get_resp_header(conn, "strict-transport-security") == []
      refute Conn.get_resp_header(conn, "expect-ct") == []
    end

    test "it does not send STS headers when disabled", %{conn: conn, base_config: base_config} do
      base_config
      |> Keyword.put(:sts, false)
      |> mock_config()

      conn = get(conn, "/api/v1/instance")

      assert Conn.get_resp_header(conn, "strict-transport-security") == []
      assert Conn.get_resp_header(conn, "expect-ct") == []
    end

    test "referrer-policy header reflects configured value", %{
      conn: conn,
      base_config: base_config
    } do
      mock_config(base_config)

      resp = get(conn, "/api/v1/instance")
      assert Conn.get_resp_header(resp, "referrer-policy") == ["same-origin"]

      base_config
      |> Keyword.put(:referrer_policy, "no-referrer")
      |> mock_config

      resp = get(conn, "/api/v1/instance")

      assert Conn.get_resp_header(resp, "referrer-policy") == ["no-referrer"]
    end

    test "it sends `report-to` & `report-uri` CSP response headers", %{
      conn: conn,
      base_config: base_config
    } do
      mock_config(base_config)

      conn = get(conn, "/api/v1/instance")

      [csp] = Conn.get_resp_header(conn, "content-security-policy")

      assert csp =~ ~r|report-uri https://endpoint.com;report-to csp-endpoint;|

      [report_to] = Conn.get_resp_header(conn, "report-to")

      assert report_to ==
               "{\"endpoints\":[{\"url\":\"https://endpoint.com\"}],\"group\":\"csp-endpoint\",\"max-age\":10886400}"
    end

    test "default values for img-src and media-src with disabled media proxy", %{
      conn: conn,
      base_config: base_config
    } do
      mock_config(base_config)
      conn = get(conn, "/api/v1/instance")

      [csp] = Conn.get_resp_header(conn, "content-security-policy")
      assert csp =~ "media-src 'self' https:;"
      assert csp =~ "img-src 'self' data: blob: https:;"
    end

    test "it sets the Service-Worker-Allowed header", %{conn: conn, base_config: base_config} do
      base_config
      |> Keyword.put(:enabled, true)

      additional_config =
        %{}
        |> Map.put([:frontends, :primary], %{"name" => "fedi-fe", "ref" => "develop"})
        |> Map.put(
          [:frontends, :available],
          %{
            "fedi-fe" => %{
              "name" => "fedi-fe",
              "custom-http-headers" => [{"service-worker-allowed", "/"}]
            }
          }
        )

      mock_config(base_config, additional_config)
      conn = get(conn, "/api/v1/instance")
      assert Conn.get_resp_header(conn, "service-worker-allowed") == ["/"]
    end
  end

  describe "img-src and media-src" do
    setup %{base_config: base_config} do
      base_config =
        base_config
        |> Keyword.put(:enabled, true)

      additional_config =
        %{}
        |> Map.put([:media_proxy, :enabled], true)
        |> Map.put([:media_proxy, :proxy_opts, :redirect_on_failure], false)
        |> Map.put([:media_proxy, :whitelist], [])

      %{base_config: base_config, additional_config: additional_config}
    end

    test "media_proxy with base_url", %{
      conn: conn,
      base_config: base_config,
      additional_config: additional_config
    } do
      url = "https://example.com"

      additional_config =
        additional_config
        |> Map.put([:media_proxy, :base_url], url)

      mock_config(base_config, additional_config)

      assert_media_img_src(conn, url)
    end

    test "upload with base url", %{
      conn: conn,
      base_config: base_config,
      additional_config: additional_config
    } do
      url = "https://example2.com"

      additional_config =
        additional_config
        |> Map.put([Pleroma.Upload, :base_url], url)

      mock_config(base_config, additional_config)

      assert_media_img_src(conn, url)
    end

    test "with S3 public endpoint", %{
      conn: conn,
      base_config: base_config,
      additional_config: additional_config
    } do
      url = "https://example3.com"

      additional_config =
        additional_config
        |> Map.put([Pleroma.Uploaders.S3, :public_endpoint], url)

      mock_config(base_config, additional_config)
      assert_media_img_src(conn, url)
    end

    test "with captcha endpoint", %{
      conn: conn,
      base_config: base_config,
      additional_config: additional_config
    } do
      additional_config =
        additional_config
        |> Map.put([Pleroma.Captcha.Mock, :endpoint], "https://captcha.com")
        |> Map.put([Pleroma.Captcha, :method], Pleroma.Captcha.Mock)

      mock_config(base_config, additional_config)
      assert_media_img_src(conn, "https://captcha.com")
    end

    test "with media_proxy whitelist", %{
      conn: conn,
      base_config: base_config,
      additional_config: additional_config
    } do
      additional_config =
        additional_config
        |> Map.put([:media_proxy, :whitelist], ["https://example6.com", "https://example7.com"])

      mock_config(base_config, additional_config)
      assert_media_img_src(conn, "https://example7.com https://example6.com")
    end

    # TODO: delete after removing support bare domains for media proxy whitelist
    test "with media_proxy bare domains whitelist (deprecated)", %{
      conn: conn,
      base_config: base_config,
      additional_config: additional_config
    } do
      additional_config =
        additional_config
        |> Map.put([:media_proxy, :whitelist], ["example4.com", "example5.com"])

      mock_config(base_config, additional_config)
      assert_media_img_src(conn, "example5.com example4.com")
    end
  end

  defp assert_media_img_src(conn, url) do
    conn = get(conn, "/api/v1/instance")
    [csp] = Conn.get_resp_header(conn, "content-security-policy")
    assert csp =~ "media-src 'self' #{url};"
    assert csp =~ "img-src 'self' data: blob: #{url};"
  end

  test "it does not send CSP headers when disabled", %{conn: conn, base_config: base_config} do
    base_config
    |> Keyword.put(:enabled, false)
    |> mock_config

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
