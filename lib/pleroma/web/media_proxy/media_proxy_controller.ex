# Pleroma: A lightweight social networking server
# Copyright © 2017-2019 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.MediaProxy.MediaProxyController do
  use Pleroma.Web, :controller
  alias Pleroma.ReverseProxy
  alias Pleroma.Web.MediaProxy

  @default_proxy_opts [max_body_length: 25 * 1_048_576, http: [follow_redirect: true]]

  def remote(conn, %{"sig" => sig64, "url" => url64} = params) do
    with config <- Pleroma.Config.get([:media_proxy], []),
         true <- Keyword.get(config, :enabled, false),
         {:ok, url} <- MediaProxy.decode_url(sig64, url64),
         :ok <- filename_matches(params, conn.request_path, url) do
      ReverseProxy.call(conn, url, Keyword.get(config, :proxy_opts, @default_proxy_opts))
    else
      false ->
        send_resp(conn, 404, Plug.Conn.Status.reason_phrase(404))

      {:error, :invalid_signature} ->
        send_resp(conn, 403, Plug.Conn.Status.reason_phrase(403))

      {:wrong_filename, filename} ->
        redirect(conn, external: MediaProxy.build_url(sig64, url64, filename))
    end
  end

  def filename_matches(%{"filename" => _} = _, path, url) do
    filename = MediaProxy.filename(url)

    if filename && does_not_match(path, filename) do
      {:wrong_filename, filename}
    else
      :ok
    end
  end

  def filename_matches(_, _, _), do: :ok

  defp does_not_match(path, filename) do
    basename = Path.basename(path)
    basename != filename and URI.decode(basename) != filename and URI.encode(basename) != filename
  end
end
