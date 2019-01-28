# Pleroma: A lightweight social networking server
# Copyright © 2017-2019 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.RichMedia.Parser do
  @parsers [
    Pleroma.Web.RichMedia.Parsers.OGP,
    Pleroma.Web.RichMedia.Parsers.TwitterCard,
    Pleroma.Web.RichMedia.Parsers.OEmbed
  ]

  def parse(nil), do: {:error, "No URL provided"}

  if Mix.env() == :test do
    def parse(url), do: parse_url(url)
  else
    def parse(url) do
      with {:ok, data} <- Cachex.fetch(:rich_media_cache, url, fn _ -> parse_url(url) end) do
        data
      else
        _e ->
          {:error, "Parsing error"}
      end
    end
  end

  defp parse_url(url) do
    try do
      {:ok, %Tesla.Env{body: html}} = Pleroma.HTTP.get(url)

      html |> maybe_parse() |> get_parsed_data()
    rescue
      _e ->
        {:error, "Parsing error"}
    end
  end

  defp maybe_parse(html) do
    Enum.reduce_while(@parsers, %{}, fn parser, acc ->
      case parser.parse(html, acc) do
        {:ok, data} -> {:halt, data}
        {:error, _msg} -> {:cont, acc}
      end
    end)
  end

  defp get_parsed_data(data) when data == %{} do
    {:error, "No metadata found"}
  end

  defp get_parsed_data(data) do
    {:ok, data}
  end
end
