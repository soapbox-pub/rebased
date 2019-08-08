# Pleroma: A lightweight social networking server
# Copyright © 2017-2019 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.RichMedia.Parsers.TwitterCard do
  alias Pleroma.Web.RichMedia.Parsers.MetaTagsParser

  @spec parse(String.t(), map()) :: {:ok, map()} | {:error, String.t()}
  def parse(html, data) do
    data
    |> parse_name_attrs(html)
    |> parse_property_attrs(html)
  end

  defp parse_name_attrs(data, html) do
    MetaTagsParser.parse(html, data, "twitter", %{}, "name")
  end

  defp parse_property_attrs({_, data}, html) do
    MetaTagsParser.parse(html, data, "twitter", "No twitter card metadata found", "property")
  end
end
