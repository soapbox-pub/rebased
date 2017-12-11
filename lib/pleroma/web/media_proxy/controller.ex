defmodule Pleroma.Web.MediaProxy.MediaProxyController do
  use Pleroma.Web, :controller
  require Logger

  @max_body_length 25 * 1048576

  @cache_control %{
    default: "public, max-age=1209600",
    error:   "public, must-revalidate, max-age=160",
  }

  def remote(conn, %{"sig" => sig, "url" => url}) do
    config = Application.get_env(:pleroma, :media_proxy, [])
    with \
      true <- Keyword.get(config, :enabled, false),
      {:ok, url} <- Pleroma.Web.MediaProxy.decode_url(sig, url),
      url = URI.encode(url),
      {:ok, content_type, body} <- proxy_request(url)
    do
      conn
      |> put_resp_content_type(content_type)
      |> set_cache_header(:default)
      |> send_resp(200, body)
    else
      false -> send_error(conn, 404)
      {:error, :invalid_signature} -> send_error(conn, 403)
      {:error, {:http, _, url}} -> redirect_or_error(conn, url, Keyword.get(config, :redirect_on_failure, true))
    end
  end

  defp proxy_request(link) do
    headers = [{"user-agent", "Pleroma/MediaProxy; #{Pleroma.Web.base_url()} <#{Application.get_env(:pleroma, :instance)[:email]}>"}]
    options = [:insecure, {:follow_redirect, true}]
    with \
      {:ok, 200, headers, client} <- :hackney.request(:get, link, headers, "", options),
      {:ok, body} <- proxy_request_body(client)
    do
      headers = Enum.into(headers, Map.new)
      {:ok, headers["Content-Type"], body}
    else
      {:ok, status, _, _} ->
        Logger.warn "MediaProxy: request failed, status #{status}, link: #{link}"
        {:error, {:http, :bad_status, link}}
      {:error, error} ->
        Logger.warn "MediaProxy: request failed, error #{inspect error}, link: #{link}"
        {:error, {:http, error, link}}
    end
  end

  defp set_cache_header(conn, key) do
    Plug.Conn.put_resp_header(conn, "cache-control", @cache_control[key])
  end

  defp redirect_or_error(conn, url, true), do: redirect(conn, external: url)
  defp redirect_or_error(conn, url, _), do: send_error(conn, 502, "Media proxy error: " <> url)

  defp send_error(conn, code, body \\ "") do
    conn
    |> set_cache_header(:error)
    |> send_resp(code, body)
  end

  defp proxy_request_body(client), do: proxy_request_body(client, <<>>)
  defp proxy_request_body(client, body) when byte_size(body) < @max_body_length do
    case :hackney.stream_body(client) do
      {:ok, data} -> proxy_request_body(client, <<body :: binary, data :: binary>>)
      :done -> {:ok, body}
      {:error, reason} -> {:error, reason}
    end
  end
  defp proxy_request_body(client, _) do
    :hackney.close(client)
    {:error, :body_too_large}
  end


end
