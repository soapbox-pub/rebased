defmodule Pleroma.Plugs.CSPPlug do
  import Plug.Conn

  def init(opts), do: opts

  def call(conn, options) do
    conn = merge_resp_headers(conn, headers())
  end

  defp headers do
    [
      {"x-xss-protection", "1; mode=block"},
      {"x-permitted-cross-domain-policies", "none"},
      {"x-frame-options", "DENY"},
      {"x-content-type-options", "nosniff"},
      {"referrer-policy", "same-origin"},
      {"x-download-options", "noopen"},
      {"content-security-policy", csp_string() <> ";"}
    ]
  end

  defp csp_string do
    [
      "default-src 'none'",
      "base-uri 'self'",
      "form-action *",
      "frame-ancestors 'none'",
      "img-src 'self' data: https:",
      "media-src 'self' https:",
      "style-src 'self' 'unsafe-inline'",
      "font-src 'self'",
      "script-src 'self'",
      "connect-src 'self' " <> String.replace(Pleroma.Web.Endpoint.static_url(), "http", "ws"),
      "upgrade-insecure-requests"
    ]
    |> Enum.join("; ")
  end
end
