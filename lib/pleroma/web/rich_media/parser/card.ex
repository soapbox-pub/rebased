# Pleroma: A lightweight social networking server
# Copyright © 2017-2021 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.RichMedia.Parser.Card do
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

  def from_oembed(%{"type" => type, "title" => title} = oembed, url) when type in @types do
    %__MODULE__{
      url: url,
      title: title,
      description: "",
      type: type,
      author_name: oembed["author_name"],
      author_url: oembed["author_url"],
      provider_name: oembed["provider_name"],
      provider_url: oembed["provider_url"],
      html: oembed["html"],
      width: oembed["width"],
      height: oembed["height"],
      image: oembed["thumbnail_url"] |> proxy(),
      embed_url: oembed["url"] |> proxy()
    }
  end

  def from_oembed(_oembed, _url), do: nil

  def from_discovery(%{"type" => "link"} = rich_media, page_url) do
    page_url_data = URI.parse(page_url)

    page_url_data =
      if is_binary(rich_media["url"]) do
        URI.merge(page_url_data, URI.parse(rich_media["url"]))
      else
        page_url_data
      end

    page_url = page_url_data |> to_string

    image_url =
      if is_binary(rich_media["image"]) do
        URI.merge(page_url_data, URI.parse(rich_media["image"]))
        |> to_string
      end

    %__MODULE__{
      type: "link",
      provider_name: page_url_data.host,
      provider_url: page_url_data.scheme <> "://" <> page_url_data.host,
      url: page_url,
      image: image_url |> proxy(),
      title: rich_media["title"] || "",
      description: rich_media["description"] || ""
    }
  end

  def from_discovery(rich_media, url), do: from_oembed(rich_media, url)

  defp proxy(url) when is_binary(url), do: Pleroma.Web.MediaProxy.url(url)
  defp proxy(_), do: nil
end
