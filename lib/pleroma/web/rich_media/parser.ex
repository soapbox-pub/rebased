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
      try do
        Cachex.fetch!(:rich_media_cache, url, fn _ ->
          {:commit, parse_url(url)}
        end)
      rescue
        e ->
          {:error, "Cachex error: #{inspect(e)}"}
      end
    end
  end

  defp parse_url(url) do
    try do
      {:ok, %Tesla.Env{body: html}} = Pleroma.HTTP.get(url)

      html |> maybe_parse() |> get_parsed_data()
    rescue
      e ->
        {:error, "Parsing error: #{inspect(e)}"}
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

  defp get_parsed_data(%{title: title} = data) when is_binary(title) and byte_size(title) > 0 do
    {:ok, data}
  end

  defp get_parsed_data(data) do
    {:error, "Found metadata was invalid or incomplete: #{inspect(data)}"}
  end
end
