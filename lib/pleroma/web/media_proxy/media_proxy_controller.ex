# Pleroma: A lightweight social networking server
# Copyright © 2017-2020 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.MediaProxy.MediaProxyController do
  use Pleroma.Web, :controller

  alias Pleroma.Config
  alias Pleroma.Helpers.MogrifyHelper
  alias Pleroma.ReverseProxy
  alias Pleroma.Web.MediaProxy

  @default_proxy_opts [max_body_length: 25 * 1_048_576, http: [follow_redirect: true]]

  def remote(conn, %{"sig" => sig64, "url" => url64} = params) do
    with config <- Config.get([:media_proxy], []),
         {_, true} <- {:enabled, Keyword.get(config, :enabled, false)},
         {:ok, url} <- MediaProxy.decode_url(sig64, url64),
         :ok <- MediaProxy.filename_matches(params, conn.request_path, url) do
      ReverseProxy.call(conn, url, Keyword.get(config, :proxy_opts, @default_proxy_opts))
    else
      {:enabled, false} ->
        send_resp(conn, 404, Plug.Conn.Status.reason_phrase(404))

      {:error, :invalid_signature} ->
        send_resp(conn, 403, Plug.Conn.Status.reason_phrase(403))

      {:wrong_filename, filename} ->
        redirect(conn, external: MediaProxy.build_url(sig64, url64, filename))
    end
  end

  def preview(conn, %{"sig" => sig64, "url" => url64} = params) do
    with {_, true} <- {:enabled, Config.get([:media_preview_proxy, :enabled], false)},
         {:ok, url} <- MediaProxy.decode_url(sig64, url64),
         :ok <- MediaProxy.filename_matches(params, conn.request_path, url) do
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
    with {:ok, %{status: status} = head_response} when status in 200..299 <- Tesla.head(url),
         {_, true} <- {:acceptable_content_length, acceptable_body_length?(head_response)} do
      content_type = Tesla.get_header(head_response, "content-type")
      handle_preview(content_type, conn, url)
    else
      {_, %{status: status}} ->
        send_resp(conn, :failed_dependency, "Can't fetch HTTP headers (HTTP #{status}).")

      {:acceptable_content_length, false} ->
        send_resp(conn, :unprocessable_entity, "Source file size exceeds limit.")
    end
  end

  defp handle_preview("image/" <> _, %{params: params} = conn, url) do
    with {:ok, %{status: status, body: body}} when status in 200..299 <- Tesla.get(url),
         {:ok, path} <- MogrifyHelper.store_as_temporary_file(url, body),
         resize_dimensions <-
           Map.get(
             params,
             "limit_dimensions",
             Config.get([:media_preview_proxy, :limit_dimensions])
           ),
         %Mogrify.Image{} <- MogrifyHelper.in_place_resize_to_limit(path, resize_dimensions) do
      send_file(conn, 200, path)
    else
      {_, %{status: _}} ->
        send_resp(conn, :failed_dependency, "Can't fetch the image.")

      _ ->
        send_resp(conn, :failed_dependency, "Can't handle image preview.")
    end
  end

  defp handle_preview(content_type, conn, _url) do
    send_resp(conn, :unprocessable_entity, "Unsupported content type: #{content_type}.")
  end

  defp acceptable_body_length?(head_response) do
    max_body_length = Config.get([:media_preview_proxy, :max_body_length], nil)
    content_length = Tesla.get_header(head_response, "content-length")
    content_length = with {int, _} <- Integer.parse(content_length), do: int

    content_length == :error or
      max_body_length in [nil, :infinity] or
      content_length <= max_body_length
  end
end
