# Pleroma: A lightweight social networking server
# Copyright © 2017-2021 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.RichMedia.Parser.Card do
  alias Pleroma.Web.RichMedia.Parser.Card
  alias Pleroma.Web.RichMedia.Parser.Embed

  @types ["link", "photo", "video", "rich"]

  # https://docs.joinmastodon.org/entities/card/
  defstruct url: nil,
            title: nil,
            description: "",
            type: "link",
            author_name: "",
            author_url: "",
            provider_name: "",
            provider_url: "",
            html: "",
            width: 0,
            height: 0,
            image: nil,
            embed_url: "",
            blurhash: nil

  def parse(%Embed{url: url, oembed: %{"type" => type, "title" => title} = oembed} = embed)
      when type in @types and is_binary(url) do
    uri = URI.parse(url)

    %Card{
      url: url,
      title: title,
      description: get_description(embed),
      type: oembed["type"],
      author_name: oembed["author_name"],
      author_url: oembed["author_url"],
      provider_name: oembed["provider_name"] || uri.host,
      provider_url: oembed["provider_url"] || "#{uri.scheme}://#{uri.host}",
      html: sanitize_html(oembed["html"]),
      width: oembed["width"],
      height: oembed["height"],
      image: get_image(oembed) |> fix_uri(url) |> proxy(),
      embed_url: oembed["url"] |> fix_uri(url) |> proxy()
    }
    |> validate()
  end

  def parse(%Embed{url: url} = embed) when is_binary(url) do
    uri = URI.parse(url)

    %Card{
      url: url,
      title: get_title(embed),
      description: get_description(embed),
      type: "link",
      provider_name: uri.host,
      provider_url: "#{uri.scheme}://#{uri.host}",
      image: get_image(embed) |> fix_uri(url) |> proxy()
    }
    |> validate()
  end

  def parse(card), do: {:error, {:invalid_metadata, card}}

  defp get_title(embed) do
    case embed do
      %{meta: %{"twitter:title" => title}} when is_binary(title) and title != "" -> title
      %{meta: %{"og:title" => title}} when is_binary(title) and title != "" -> title
      %{title: title} when is_binary(title) and title != "" -> title
      _ -> nil
    end
  end

  defp get_description(%{meta: meta}) do
    case meta do
      %{"twitter:description" => desc} when is_binary(desc) and desc != "" -> desc
      %{"og:description" => desc} when is_binary(desc) and desc != "" -> desc
      %{"description" => desc} when is_binary(desc) and desc != "" -> desc
      _ -> ""
    end
  end

  defp get_image(%{meta: meta}) do
    case meta do
      %{"twitter:image" => image} when is_binary(image) and image != "" -> image
      %{"og:image" => image} when is_binary(image) and image != "" -> image
      _ -> ""
    end
  end

  defp get_image(%{"thumbnail_url" => image}) when is_binary(image) and image != "", do: image
  defp get_image(%{"type" => "photo", "url" => image}), do: image
  defp get_image(_), do: ""

  defp sanitize_html(html) do
    with {:ok, html} <- FastSanitize.Sanitizer.scrub(html, Pleroma.HTML.Scrubber.OEmbed),
         {:ok, [{"iframe", _, _}]} <- Floki.parse_fragment(html) do
      html
    else
      _ -> ""
    end
  end

  def to_map(%Card{} = card) do
    card
    |> Map.from_struct()
    |> stringify_keys()
  end

  def to_map(%{} = card), do: stringify_keys(card)

  defp stringify_keys(%{} = map), do: Map.new(map, fn {k, v} -> {Atom.to_string(k), v} end)

  def fix_uri("http://" <> _ = uri, _base_uri), do: uri
  def fix_uri("https://" <> _ = uri, _base_uri), do: uri
  def fix_uri("/" <> _ = uri, base_uri), do: URI.merge(base_uri, uri) |> URI.to_string()
  def fix_uri("", _base_uri), do: nil

  def fix_uri(uri, base_uri) when is_binary(uri),
    do: URI.merge(base_uri, "/#{uri}") |> URI.to_string()

  def fix_uri(_uri, _base_uri), do: nil

  defp proxy(url) when is_binary(url), do: Pleroma.Web.MediaProxy.url(url)
  defp proxy(_), do: nil

  def validate(%Card{type: type, html: html} = card)
      when type in ["video", "rich"] and (is_binary(html) == false or html == "") do
    card
    |> Map.put(:type, "link")
    |> validate()
  end

  def validate(%Card{type: type, title: title} = card)
      when type in @types and is_binary(title) and title != "" do
    {:ok, card}
  end

  def validate(%Embed{} = embed) do
    case Card.parse(embed) do
      {:ok, %Card{} = card} -> validate(card)
      card -> {:error, {:invalid_metadata, card}}
    end
  end

  def validate(card), do: {:error, {:invalid_metadata, card}}
end
