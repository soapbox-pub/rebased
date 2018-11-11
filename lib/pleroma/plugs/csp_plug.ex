defmodule Pleroma.Plugs.CSPPlug do
  alias Pleroma.Config
  import Plug.Conn

  def init(opts), do: opts

  def call(conn, options) do
    if Config.get([:csp, :enabled]) do
      conn =
        merge_resp_headers(conn, headers())
        |> maybe_send_sts_header(Config.get([:csp, :sts]))
    else
      conn
    end
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

  defp maybe_send_sts_header(conn, true) do
    max_age = Config.get([:csp, :sts_max_age])

    merge_resp_headers(conn, [
      {"strict-transport-security", "max-age=#{max_age}; includeSubDomains"}
    ])
  end

  defp maybe_send_sts_header(conn, _), do: conn
end
