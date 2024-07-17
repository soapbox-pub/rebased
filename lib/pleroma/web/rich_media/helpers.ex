# Pleroma: A lightweight social networking server
# Copyright © 2017-2022 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.RichMedia.Helpers do
  alias Pleroma.Config

  require Logger

  @type get_errors :: {:error, :body_too_large | :content_type | :head | :get}

  @spec rich_media_get(String.t()) :: {:ok, String.t()} | get_errors()
  def rich_media_get(url) do
    headers = [{"user-agent", Pleroma.Application.user_agent() <> "; Bot"}]

    with {_, {:ok, %Tesla.Env{status: 200, headers: headers}}} <-
           {:head, Pleroma.HTTP.head(url, headers, http_options())},
         {_, :ok} <- {:content_type, check_content_type(headers)},
         {_, :ok} <- {:content_length, check_content_length(headers)},
         {_, {:ok, %Tesla.Env{status: 200, body: body}}} <-
           {:get, Pleroma.HTTP.get(url, headers, http_options())} do
      {:ok, body}
    else
      {:head, _} ->
        Logger.debug("Rich media error for #{url}: HTTP HEAD failed")
        {:error, :head}

      {:content_type, {_, type}} ->
        Logger.debug("Rich media error for #{url}: content-type is #{type}")
        {:error, :content_type}

      {:content_length, {_, length}} ->
        Logger.debug("Rich media error for #{url}: content-length is #{length}")
        {:error, :body_too_large}

      {:get, _} ->
        Logger.debug("Rich media error for #{url}: HTTP GET failed")
        {:error, :get}
    end
  end

  defp check_content_type(headers) do
    case List.keyfind(headers, "content-type", 0) do
      {_, content_type} ->
        case Plug.Conn.Utils.media_type(content_type) do
          {:ok, "text", "html", _} -> :ok
          _ -> {:error, content_type}
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
          {_, ""} -> {:error, maybe_content_length}
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
