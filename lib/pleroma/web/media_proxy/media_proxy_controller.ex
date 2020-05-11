# Pleroma: A lightweight social networking server
# Copyright © 2017-2020 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.MediaProxy.MediaProxyController do
  use Pleroma.Web, :controller

  alias Pleroma.Config
  alias Pleroma.Helpers.MogrifyHelper
  alias Pleroma.ReverseProxy
  alias Pleroma.Web.MediaProxy

  def remote(conn, %{"sig" => sig64, "url" => url64}) do
    with {_, true} <- {:enabled, MediaProxy.enabled?()},
         {:ok, url} <- MediaProxy.decode_url(sig64, url64),
         :ok <- MediaProxy.verify_request_path_and_url(conn, url) do
      proxy_opts = Config.get([:media_proxy, :proxy_opts], [])
      ReverseProxy.call(conn, url, proxy_opts)
    else
      {:enabled, false} ->
        send_resp(conn, 404, Plug.Conn.Status.reason_phrase(404))

      {:error, :invalid_signature} ->
        send_resp(conn, 403, Plug.Conn.Status.reason_phrase(403))

      {:wrong_filename, filename} ->
        redirect(conn, external: MediaProxy.build_url(sig64, url64, filename))
    end
  end

  def preview(conn, %{"sig" => sig64, "url" => url64}) do
    with {_, true} <- {:enabled, MediaProxy.preview_enabled?()},
         {:ok, url} <- MediaProxy.decode_url(sig64, url64),
         :ok <- MediaProxy.verify_request_path_and_url(conn, url) do
      handle_preview(conn, url)
    else
      {:enabled, false} ->
        send_resp(conn, 404, Plug.Conn.Status.reason_phrase(404))

      {:error, :invalid_signature} ->
        send_resp(conn, 403, Plug.Conn.Status.reason_phrase(403))

      {:wrong_filename, filename} ->
        redirect(conn, external: MediaProxy.build_preview_url(sig64, url64, filename))
    end
  end

  defp handle_preview(conn, url) do
    with {:ok, %{status: status} = head_response} when status in 200..299 <-
           Tesla.head(url, opts: [adapter: [timeout: preview_head_request_timeout()]]) do
      content_type = Tesla.get_header(head_response, "content-type")
      handle_preview(content_type, conn, url)
    else
      {_, %{status: status}} ->
        send_resp(conn, :failed_dependency, "Can't fetch HTTP headers (HTTP #{status}).")

      {:error, :recv_response_timeout} ->
        send_resp(conn, :failed_dependency, "HEAD request timeout.")

      _ ->
        send_resp(conn, :failed_dependency, "Can't fetch HTTP headers.")
    end
  end

  defp handle_preview("image/" <> _ = content_type, %{params: params} = conn, url) do
    with {:ok, %{status: status, body: body}} when status in 200..299 <-
           url
           |> MediaProxy.url()
           |> Tesla.get(opts: [adapter: [timeout: preview_timeout()]]),
         {:ok, path} <- MogrifyHelper.store_as_temporary_file(url, body),
         resize_dimensions <-
           Map.get(
             params,
             "limit_dimensions",
             Config.get([:media_preview_proxy, :limit_dimensions])
           ),
         %Mogrify.Image{} <- MogrifyHelper.in_place_resize_to_limit(path, resize_dimensions),
         {:ok, image_binary} <- File.read(path),
         _ <- File.rm(path) do
      conn
      |> put_resp_header("content-type", content_type)
      |> send_resp(200, image_binary)
    else
      {_, %{status: _}} ->
        send_resp(conn, :failed_dependency, "Can't fetch the image.")

      {:error, :recv_response_timeout} ->
        send_resp(conn, :failed_dependency, "Downstream timeout.")

      _ ->
        send_resp(conn, :failed_dependency, "Can't handle image preview.")
    end
  end

  defp handle_preview(content_type, conn, _url) do
    send_resp(conn, :unprocessable_entity, "Unsupported content type: #{content_type}.")
  end

  defp preview_head_request_timeout do
    Config.get([:media_preview_proxy, :proxy_opts, :head_request_max_read_duration]) ||
      preview_timeout()
  end

  defp preview_timeout do
    Config.get([:media_preview_proxy, :proxy_opts, :max_read_duration]) ||
      Config.get([:media_proxy, :proxy_opts, :max_read_duration]) ||
      ReverseProxy.max_read_duration_default()
  end
end
