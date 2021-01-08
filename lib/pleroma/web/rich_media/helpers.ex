# Pleroma: A lightweight social networking server
# Copyright _ 2017-2020 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.RichMedia.Helpers do
  alias Pleroma.Activity
  alias Pleroma.Config
  alias Pleroma.HTML
  alias Pleroma.Object
  alias Pleroma.Web.RichMedia.Parser

  @options [
    pool: :media,
    max_body: 2_000_000,
    recv_timeout: 2_000
  ]

  @spec validate_page_url(URI.t() | binary()) :: :ok | :error
  defp validate_page_url(page_url) when is_binary(page_url) do
    validate_tld = Config.get([Pleroma.Formatter, :validate_tld])

    page_url
    |> Linkify.Parser.url?(validate_tld: validate_tld)
    |> parse_uri(page_url)
  end

  defp validate_page_url(%URI{host: host, scheme: "https", authority: authority})
       when is_binary(authority) do
    cond do
      host in Config.get([:rich_media, :ignore_hosts], []) ->
        :error

      get_tld(host) in Config.get([:rich_media, :ignore_tld], []) ->
        :error

      true ->
        :ok
    end
  end

  defp validate_page_url(_), do: :error

  defp parse_uri(true, url) do
    url
    |> URI.parse()
    |> validate_page_url
  end

  defp parse_uri(_, _), do: :error

  defp get_tld(host) do
    host
    |> String.split(".")
    |> Enum.reverse()
    |> hd
  end

  def fetch_data_for_object(object) do
    with true <- Config.get([:rich_media, :enabled]),
         {:ok, page_url} <-
           HTML.extract_first_external_url_from_object(object),
         :ok <- validate_page_url(page_url),
         {:ok, rich_media} <- Parser.parse(page_url) do
      %{page_url: page_url, rich_media: rich_media}
    else
      _ -> %{}
    end
  end

  def fetch_data_for_activity(%Activity{data: %{"type" => "Create"}} = activity) do
    with true <- Config.get([:rich_media, :enabled]),
         %Object{} = object <- Object.normalize(activity, fetch: false) do
      fetch_data_for_object(object)
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
