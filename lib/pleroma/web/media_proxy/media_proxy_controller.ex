# Pleroma: A lightweight social networking server
# Copyright © 2017-2022 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.MediaProxy.MediaProxyController do
  use Pleroma.Web, :controller

  alias Pleroma.Config
  alias Pleroma.Helpers.MediaHelper
  alias Pleroma.Helpers.UriHelper
  alias Pleroma.ReverseProxy
  alias Pleroma.Web.MediaProxy
  alias Plug.Conn

  def remote(conn, %{"sig" => sig64, "url" => url64}) do
    with {_, true} <- {:enabled, MediaProxy.enabled?()},
         {:ok, url} <- MediaProxy.decode_url(sig64, url64),
         {_, false} <- {:in_banned_urls, MediaProxy.in_banned_urls(url)},
         :ok <- MediaProxy.verify_request_path_and_url(conn, url) do
      ReverseProxy.call(conn, url, media_proxy_opts())
    else
      {:enabled, false} ->
        send_resp(conn, 404, Conn.Status.reason_phrase(404))

      {:in_banned_urls, true} ->
        send_resp(conn, 404, Conn.Status.reason_phrase(404))

      {:error, :invalid_signature} ->
        send_resp(conn, 403, Conn.Status.reason_phrase(403))

      {:wrong_filename, filename} ->
        redirect(conn, external: MediaProxy.build_url(sig64, url64, filename))
    end
  end

  def preview(%Conn{} = conn, %{"sig" => sig64, "url" => url64}) do
    with {_, true} <- {:enabled, MediaProxy.preview_enabled?()},
         {:ok, url} <- MediaProxy.decode_url(sig64, url64),
         :ok <- MediaProxy.verify_request_path_and_url(conn, url) do
      handle_preview(conn, url)
    else
      {:enabled, false} ->
        send_resp(conn, 404, Conn.Status.reason_phrase(404))

      {:error, :invalid_signature} ->
        send_resp(conn, 403, Conn.Status.reason_phrase(403))

      {:wrong_filename, filename} ->
        redirect(conn, external: MediaProxy.build_preview_url(sig64, url64, filename))
    end
  end

  defp handle_preview(conn, url) do
    media_proxy_url = MediaProxy.url(url)

    with {:ok, %{status: status} = head_response} when status in 200..299 <-
           Pleroma.HTTP.request("head", media_proxy_url, [], [], pool: :media) do
      content_type = Tesla.get_header(head_response, "content-type")
      content_length = Tesla.get_header(head_response, "content-length")
      content_length = content_length && String.to_integer(content_length)
      static = conn.params["static"] in ["true", true]

      cond do
        static and content_type == "image/gif" ->
          handle_jpeg_preview(conn, media_proxy_url)

        static ->
          drop_static_param_and_redirect(conn)

        content_type == "image/gif" ->
          redirect(conn, external: media_proxy_url)

        min_content_length_for_preview() > 0 and content_length > 0 and
            content_length < min_content_length_for_preview() ->
          redirect(conn, external: media_proxy_url)

        true ->
          handle_preview(content_type, conn, media_proxy_url)
      end
    else
      # If HEAD failed, redirecting to media proxy URI doesn't make much sense; returning an error
      {_, %{status: status}} ->
        send_resp(conn, :failed_dependency, "Can't fetch HTTP headers (HTTP #{status}).")

      {:error, :recv_response_timeout} ->
        send_resp(conn, :failed_dependency, "HEAD request timeout.")

      _ ->
        send_resp(conn, :failed_dependency, "Can't fetch HTTP headers.")
    end
  end

  defp handle_preview("image/png" <> _ = _content_type, conn, media_proxy_url) do
    handle_png_preview(conn, media_proxy_url)
  end

  defp handle_preview("image/" <> _ = _content_type, conn, media_proxy_url) do
    handle_jpeg_preview(conn, media_proxy_url)
  end

  defp handle_preview("video/" <> _ = _content_type, conn, media_proxy_url) do
    handle_video_preview(conn, media_proxy_url)
  end

  defp handle_preview(_unsupported_content_type, conn, media_proxy_url) do
    fallback_on_preview_error(conn, media_proxy_url)
  end

  defp handle_png_preview(conn, media_proxy_url) do
    quality = Config.get!([:media_preview_proxy, :image_quality])
    {thumbnail_max_width, thumbnail_max_height} = thumbnail_max_dimensions()

    with {:ok, thumbnail_binary} <-
           MediaHelper.image_resize(
             media_proxy_url,
             %{
               max_width: thumbnail_max_width,
               max_height: thumbnail_max_height,
               quality: quality,
               format: "png"
             }
           ) do
      conn
      |> put_preview_response_headers(["image/png", "preview.png"])
      |> send_resp(200, thumbnail_binary)
    else
      _ ->
        fallback_on_preview_error(conn, media_proxy_url)
    end
  end

  defp handle_jpeg_preview(conn, media_proxy_url) do
    quality = Config.get!([:media_preview_proxy, :image_quality])
    {thumbnail_max_width, thumbnail_max_height} = thumbnail_max_dimensions()

    with {:ok, thumbnail_binary} <-
           MediaHelper.image_resize(
             media_proxy_url,
             %{max_width: thumbnail_max_width, max_height: thumbnail_max_height, quality: quality}
           ) do
      conn
      |> put_preview_response_headers()
      |> send_resp(200, thumbnail_binary)
    else
      _ ->
        fallback_on_preview_error(conn, media_proxy_url)
    end
  end

  defp handle_video_preview(conn, media_proxy_url) do
    with {:ok, thumbnail_binary} <-
           MediaHelper.video_framegrab(media_proxy_url) do
      conn
      |> put_preview_response_headers()
      |> send_resp(200, thumbnail_binary)
    else
      _ ->
        fallback_on_preview_error(conn, media_proxy_url)
    end
  end

  defp drop_static_param_and_redirect(conn) do
    uri_without_static_param =
      conn
      |> current_url()
      |> UriHelper.modify_uri_params(%{}, ["static"])

    redirect(conn, external: uri_without_static_param)
  end

  defp fallback_on_preview_error(conn, media_proxy_url) do
    redirect(conn, external: media_proxy_url)
  end

  defp put_preview_response_headers(
         conn,
         [content_type, filename] = _content_info \\ ["image/jpeg", "preview.jpg"]
       ) do
    conn
    |> put_resp_header("content-type", content_type)
    |> put_resp_header("content-disposition", "inline; filename=\"#{filename}\"")
    |> put_resp_header("cache-control", ReverseProxy.default_cache_control_header())
  end

  defp thumbnail_max_dimensions do
    config = media_preview_proxy_config()

    thumbnail_max_width = Keyword.fetch!(config, :thumbnail_max_width)
    thumbnail_max_height = Keyword.fetch!(config, :thumbnail_max_height)

    {thumbnail_max_width, thumbnail_max_height}
  end

  defp min_content_length_for_preview do
    Keyword.get(media_preview_proxy_config(), :min_content_length, 0)
  end

  defp media_preview_proxy_config do
    Config.get!([:media_preview_proxy])
  end

  defp media_proxy_opts do
    Config.get([:media_proxy, :proxy_opts], [])
  end
end
