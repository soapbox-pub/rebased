defmodule Pleroma.Web.MediaProxy.MediaProxyController do
  use Pleroma.Web, :controller
  require Logger

  def remote(conn, %{"sig" => sig, "url" => url}) do
    {:ok, url} = Pleroma.Web.MediaProxy.decode_url(sig, url)
    url = url |> URI.encode()
    case proxy_request(url) do
      {:ok, content_type, body} ->
        conn
        |> put_resp_content_type(content_type)
        |> set_cache_header(:default)
        |> send_resp(200, body)
      other ->
        conn
        |> set_cache_header(:error)
        |> redirect(external: url)
    end
  end

  defp proxy_request(link) do
    headers = [{"user-agent", "Pleroma/MediaProxy; #{Pleroma.Web.base_url()} <#{Application.get_env(:pleroma, :instance)[:email]}>"}]
    options = [:insecure, {:follow_redirect, true}]
    case :hackney.request(:get, link, headers, "", options) do
      {:ok, 200, headers, client} ->
        headers = Enum.into(headers, Map.new)
        {:ok, body} = :hackney.body(client)
        {:ok, headers["Content-Type"], body}
      {:ok, status, _, _} ->
        Logger.warn "MediaProxy: request failed, status #{status}, link: #{link}"
        {:error, :bad_status}
      {:error, error} ->
        Logger.warn "MediaProxy: request failed, error #{inspect error}, link: #{link}"
        {:error, error}
    end
  end

  @cache_control %{
    default: "public, max-age=1209600",
    error:   "public, must-revalidate, max-age=160",
  }

  defp set_cache_header(conn, true), do: set_cache_header(conn, :default)
  defp set_cache_header(conn, false), do: set_cache_header(conn, :error)
  defp set_cache_header(conn, key) when is_atom(key), do: set_cache_header(conn, @cache_control[key])
  defp set_cache_header(conn, value) when is_binary(value), do: Plug.Conn.put_resp_header(conn, "cache-control", value)

end
