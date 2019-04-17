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
