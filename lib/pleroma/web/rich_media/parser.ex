# Pleroma: A lightweight social networking server
# Copyright © 2017-2022 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.RichMedia.Parser do
  alias Pleroma.Web.RichMedia.Helpers
  require Logger

  @config_impl Application.compile_env(:pleroma, [__MODULE__, :config_impl], Pleroma.Config)

  defp parsers do
    Pleroma.Config.get([:rich_media, :parsers])
  end

  @type parse_errors :: {:error, :rich_media_disabled | :validate}

  @spec parse(String.t()) ::
          {:ok, map()} | parse_errors() | Helpers.get_errors()
  def parse(url) when is_binary(url) do
    with {_, true} <- {:config, @config_impl.get([:rich_media, :enabled])},
         {_, :ok} <- {:validate, validate_page_url(url)},
         {_, {:ok, data}} <- {:parse, parse_url(url)} do
      data = Map.put(data, "url", url)
      {:ok, data}
    else
      {:config, _} -> {:error, :rich_media_disabled}
      {:validate, _} -> {:error, :validate}
      {:parse, error} -> error
    end
  end

  defp parse_url(url) do
    with {:ok, body} <- Helpers.rich_media_get(url),
         {:ok, html} <- Floki.parse_document(body) do
      html
      |> maybe_parse()
      |> clean_parsed_data()
      |> check_parsed_data()
    end
  end

  defp maybe_parse(html) do
    Enum.reduce_while(parsers(), %{}, fn parser, acc ->
      case parser.parse(html, acc) do
        data when data != %{} -> {:halt, data}
        _ -> {:cont, acc}
      end
    end)
  end

  defp check_parsed_data(%{"title" => title} = data)
       when is_binary(title) and title != "" do
    {:ok, data}
  end

  defp check_parsed_data(_data) do
    {:error, :invalid_metadata}
  end

  defp clean_parsed_data(data) do
    data
    |> Enum.reject(fn {key, val} ->
      not match?({:ok, _}, Jason.encode(%{key => val}))
    end)
    |> Map.new()
  end

  @spec validate_page_url(URI.t() | binary()) :: :ok | :error
  defp validate_page_url(page_url) when is_binary(page_url) do
    validate_tld = @config_impl.get([Pleroma.Formatter, :validate_tld])

    page_url
    |> Linkify.Parser.url?(validate_tld: validate_tld)
    |> parse_uri(page_url)
  end

  defp validate_page_url(%URI{host: host, scheme: "https"}) do
    cond do
      Linkify.Parser.ip?(host) ->
        :error

      host in @config_impl.get([:rich_media, :ignore_hosts], []) ->
        :error

      get_tld(host) in @config_impl.get([:rich_media, :ignore_tld], []) ->
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
end
