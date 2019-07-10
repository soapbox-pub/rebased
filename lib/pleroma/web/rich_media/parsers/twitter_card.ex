# Pleroma: A lightweight social networking server
# Copyright © 2017-2019 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.RichMedia.Parsers.TwitterCard do
  def parse(html, data) do
    Pleroma.Web.RichMedia.Parsers.MetaTagsParser.parse(
      html,
      data,
      "twitter",
      "No twitter card metadata found",
      "name"
    )
  end
end
