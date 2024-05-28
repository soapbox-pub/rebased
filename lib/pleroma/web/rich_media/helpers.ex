# Pleroma: A lightweight social networking server
# Copyright © 2017-2022 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.RichMedia.Helpers do
  alias Pleroma.Config

  defp headers do
    user_agent =
      case Pleroma.Config.get([:rich_media, :user_agent], :default) do
        :default ->
          Pleroma.Application.user_agent() <> "; Bot"

        custom ->
          custom
      end

    [{"user-agent", user_agent}]
  end

  def rich_media_get(url) do
    headers = headers()

    head_check =
      case Pleroma.HTTP.head(url, headers, http_options()) do
        # If the HEAD request didn't reach the server for whatever reason,
        # we assume the GET that comes right after won't either
        {:error, _} = e ->
          e

        {:ok, %Tesla.Env{status: 200, headers: headers}} ->
          with :ok <- check_content_type(headers),
               :ok <- check_content_length(headers),
               do: :ok

        _ ->
          :ok
      end

    with :ok <- head_check, do: Pleroma.HTTP.get(url, headers, http_options())
  end

  defp check_content_type(headers) do
    case List.keyfind(headers, "content-type", 0) do
      {_, content_type} ->
        case Plug.Conn.Utils.media_type(content_type) do
          {:ok, "text", "html", _} -> :ok
          _ -> {:error, {:content_type, content_type}}
        end

      _ ->
        :ok
    end
  end

  defp check_content_length(headers) do
    max_body = Keyword.get(http_options(), :max_body)

    case List.keyfind(headers, "content-length", 0) do
      {_, maybe_content_length} ->
        case Integer.parse(maybe_content_length) do
          {content_length, ""} when content_length <= max_body -> :ok
          {_, ""} -> {:error, :body_too_large}
          _ -> :ok
        end

      _ ->
        :ok
    end
  end

  defp http_options do
    [
      pool: :rich_media,
      max_body: Config.get([:rich_media, :max_body], 5_000_000)
    ]
  end
end
