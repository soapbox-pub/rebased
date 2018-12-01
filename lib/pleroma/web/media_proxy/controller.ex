defmodule Pleroma.Web.MediaProxy.MediaProxyController do
  use Pleroma.Web, :controller
  alias Pleroma.{Web.MediaProxy, ReverseProxy}

  @default_proxy_opts [max_body_length: 25 * 1_048_576]

  def remote(conn, params = %{"sig" => sig64, "url" => url64}) do
    with config <- Pleroma.Config.get([:media_proxy]),
         true <- Keyword.get(config, :enabled, false),
         {:ok, url} <- MediaProxy.decode_url(sig64, url64),
         filename <- Path.basename(URI.parse(url).path),
         :ok <- filename_matches(Map.has_key?(params, "filename"), conn.request_path, url) do
      ReverseProxy.call(conn, url, Keyword.get(config, :proxy_opts, @default_proxy_length))
    else
      false ->
        send_resp(conn, 404, Plug.Conn.Status.reason_phrase(404))

      {:error, :invalid_signature} ->
        send_resp(conn, 403, Plug.Conn.Status.reason_phrase(403))

      {:wrong_filename, filename} ->
        redirect(conn, external: MediaProxy.build_url(sig64, url64, filename))
    end
  end

  def filename_matches(has_filename, path, url) do
    filename = MediaProxy.filename(url)

    cond do
      has_filename && filename && Path.basename(path) != filename -> {:wrong_filename, filename}
      true -> :ok
    end
  end
end
