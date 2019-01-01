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
    protocol = Config.get([Pleroma.Web.Endpoint, :protocol])

    [
      "default-src 'none'",
      "base-uri 'self'",
      "frame-ancestors 'none'",
      "img-src 'self' data: https:",
      "media-src 'self' https:",
      "style-src 'self' 'unsafe-inline'",
      "font-src 'self'",
      "script-src 'self'",
      "connect-src 'self' " <> String.replace(Pleroma.Web.Endpoint.static_url(), "http", "ws"),
      "manifest-src 'self'",
      if protocol == "https" do
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
