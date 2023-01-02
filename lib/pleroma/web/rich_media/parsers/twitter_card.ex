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
  end
end
