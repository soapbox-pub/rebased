# Pleroma: A lightweight social networking server
# Copyright © 2017-2022 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.RichMedia.Parsers.TwitterCard do
  alias Pleroma.Web.RichMedia.Parsers.MetaTagsParser

  @spec parse(list(), map()) :: map()
  def parse(html, data) do
    data
    |> MetaTagsParser.parse(html, "og", "property")
    |> MetaTagsParser.parse(html, "twitter", "name")
    |> MetaTagsParser.parse(html, "twitter", "property")
    |> filter_tags()
  end

  defp filter_tags(tags) do
    Map.filter(tags, fn {k, _v} ->
      cond do
        k in ["card", "description", "image", "title", "ttl", "type", "url"] -> true
        String.starts_with?(k, "image:") -> true
        true -> false
      end
    end)
  end
end
