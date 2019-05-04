# Pleroma: A lightweight social networking server
# Copyright © 2017-2019 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Plugs.HTTPSecurityPlug do
  alias Pleroma.Config
  import Plug.Conn

  def init(opts), do: opts

  def call(conn, _options) do
    if Config.get([:http_security, :enabled]) do
      conn
      |> merge_resp_headers(headers())
      |> maybe_send_sts_header(Config.get([:http_security, :sts]))
    else
      conn
    end
  end

  defp headers do
    referrer_policy = Config.get([:http_security, :referrer_policy])

    [
      {"x-xss-protection", "1; mode=block"},
      {"x-permitted-cross-domain-policies", "none"},
      {"x-frame-options", "DENY"},
      {"x-content-type-options", "nosniff"},
      {"referrer-policy", referrer_policy},
      {"x-download-options", "noopen"},
      {"content-security-policy", csp_string() <> ";"}
    ]
  end

  defp csp_string do
    scheme = Config.get([Pleroma.Web.Endpoint, :url])[:scheme]
    static_url = Pleroma.Web.Endpoint.static_url()
    websocket_url = Pleroma.Web.Endpoint.websocket_url()

    connect_src = "connect-src 'self' #{static_url} #{websocket_url}"

    connect_src =
      if Mix.env() == :dev do
        connect_src <> " http://localhost:3035/"
      else
        connect_src
      end

    script_src =
      if Mix.env() == :dev do
        "script-src 'self' 'unsafe-eval'"
      else
        "script-src 'self'"
      end

    [
      "default-src 'none'",
      "base-uri 'self'",
      "frame-ancestors 'none'",
      "img-src 'self' data: https:",
      "media-src 'self' https:",
      "style-src 'self' 'unsafe-inline'",
      "font-src 'self'",
      "manifest-src 'self'",
      connect_src,
      script_src,
      if scheme == "https" do
        "upgrade-insecure-requests"
      end
    ]
    |> Enum.join("; ")
  end

  defp maybe_send_sts_header(conn, true) do
    max_age_sts = Config.get([:http_security, :sts_max_age])
    max_age_ct = Config.get([:http_security, :ct_max_age])

    merge_resp_headers(conn, [
      {"strict-transport-security", "max-age=#{max_age_sts}; includeSubDomains"},
      {"expect-ct", "enforce, max-age=#{max_age_ct}"}
    ])
  end

  defp maybe_send_sts_header(conn, _), do: conn
end
