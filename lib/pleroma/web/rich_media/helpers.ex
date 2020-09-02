# Pleroma: A lightweight social networking server
# Copyright _ 2017-2020 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.RichMedia.Helpers do
  alias Pleroma.Activity
  alias Pleroma.Config
  alias Pleroma.HTML
  alias Pleroma.Object
  alias Pleroma.Web.RichMedia.Parser

  @rich_media_options [
    pool: :media,
    max_body: 2_000_000
  ]

  @spec validate_page_url(URI.t() | binary()) :: :ok | :error
  defp validate_page_url(page_url) when is_binary(page_url) do
    validate_tld = Pleroma.Config.get([Pleroma.Formatter, :validate_tld])

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
         false <- object.data["sensitive"] || false,
         {:ok, page_url} <-
           HTML.extract_first_external_url(object, object.data["content"]),
         :ok <- validate_page_url(page_url),
         {:ok, rich_media} <- Parser.parse(page_url) do
      %{page_url: page_url, rich_media: rich_media}
    else
      _ -> %{}
    end
  end

  def fetch_data_for_activity(%Activity{data: %{"type" => "Create"}} = activity) do
    with true <- Config.get([:rich_media, :enabled]),
         %Object{} = object <- Object.normalize(activity) do
      fetch_data_for_object(object)
    else
      _ -> %{}
    end
  end

  def fetch_data_for_activity(_), do: %{}

  def perform(:fetch, %Activity{} = activity) do
    fetch_data_for_activity(activity)
    :ok
  end

  def rich_media_get(url) do
    headers = [{"user-agent", Pleroma.Application.user_agent() <> "; Bot"}]

    options =
      if Application.get_env(:tesla, :adapter) == Tesla.Adapter.Hackney do
        Keyword.merge(@rich_media_options,
          recv_timeout: 2_000,
          with_body: true
        )
      else
        @rich_media_options
      end

    Pleroma.HTTP.get(url, headers, adapter: options)
  end
end
