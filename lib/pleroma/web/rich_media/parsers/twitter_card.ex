# Pleroma: A lightweight social networking server
# Copyright © 2017-2021 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.RichMedia.Parsers.TwitterCard do
  alias Pleroma.Web.RichMedia.Parsers.MetaTagsParser

  @spec parse(list(), map()) :: map()
  def parse(html, data) do
    data
    |> Map.put(:title, MetaTagsParser.get_page_title(html))
    |> Map.put(:opengraph, MetaTagsParser.parse(html, "og", "property"))
    |> Map.put(:twitter, MetaTagsParser.parse(html, "twitter", ["name", "property"]))
  end
end
