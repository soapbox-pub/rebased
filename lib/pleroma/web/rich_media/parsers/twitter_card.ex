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
