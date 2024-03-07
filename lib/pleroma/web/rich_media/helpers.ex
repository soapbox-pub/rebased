# Pleroma: A lightweight social networking server
# Copyright © 2017-2022 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.RichMedia.Helpers do
  alias Pleroma.Activity
  alias Pleroma.HTML
  alias Pleroma.Object
  alias Pleroma.Web.RichMedia.Parser

  @cachex Pleroma.Config.get([:cachex, :provider], Cachex)

  @config_impl Application.compile_env(:pleroma, [__MODULE__, :config_impl], Pleroma.Config)

  @options [
    pool: :media,
    max_body: 2_000_000,
    recv_timeout: 2_000
  ]

  def fetch_data_for_object(object) do
    with true <- @config_impl.get([:rich_media, :enabled]),
         {:ok, page_url} <-
           HTML.extract_first_external_url_from_object(object),
         {:ok, rich_media} <- Parser.parse(page_url) do
      %{page_url: page_url, rich_media: rich_media}
    else
      _ -> %{}
    end
  end

  def fetch_data_for_activity(%Activity{data: %{"type" => "Create"}} = activity) do
    with true <- @config_impl.get([:rich_media, :enabled]),
         %Object{} = object <- Object.normalize(activity, fetch: false) do
      if object.data["fake"] do
        fetch_data_for_object(object)
      else
        key = "URL|#{activity.id}"

        @cachex.fetch!(:scrubber_cache, key, fn _ ->
          result = fetch_data_for_object(object)

          cond do
            match?(%{page_url: _, rich_media: _}, result) ->
              Activity.HTML.add_cache_key_for(activity.id, key)
              {:commit, result}

            true ->
              {:ignore, %{}}
          end
        end)
      end
    else
      _ -> %{}
    end
  end

  def fetch_data_for_activity(_), do: %{}

  def rich_media_get(url) do
    headers = [{"user-agent", Pleroma.Application.user_agent() <> "; Bot"}]

    head_check =
      case Pleroma.HTTP.head(url, headers, @options) do
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

    with :ok <- head_check, do: Pleroma.HTTP.get(url, headers, @options)
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

  @max_body @options[:max_body]
  defp check_content_length(headers) do
    case List.keyfind(headers, "content-length", 0) do
      {_, maybe_content_length} ->
        case Integer.parse(maybe_content_length) do
          {content_length, ""} when content_length <= @max_body -> :ok
          {_, ""} -> {:error, :body_too_large}
          _ -> :ok
        end

      _ ->
        :ok
    end
  end
end
