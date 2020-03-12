# Pleroma: A lightweight social networking server
# Copyright © 2017-2020 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.RichMedia.Parsers.OGP do
  def parse(html, data) do
    Pleroma.Web.RichMedia.Parsers.MetaTagsParser.parse(
      html,
      data,
      "og",
      "No OGP metadata found",
      "property"
    )
  end
end
