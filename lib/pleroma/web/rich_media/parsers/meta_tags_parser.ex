# Pleroma: A lightweight social networking server
# Copyright © 2017-2021 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.RichMedia.Parsers.MetaTagsParser do
  def parse(data, html, prefix, key_name, value_name \\ "content") do
    html
    |> get_elements(key_name, prefix)
    |> Enum.reduce(data, fn el, acc ->
      attributes = normalize_attributes(el, prefix, key_name, value_name)

      Map.merge(acc, attributes)
    end)
    |> maybe_put_title(html)
  end

  defp get_elements(html, key_name, prefix) do
    html |> Floki.find("meta[#{key_name}^='#{prefix}:']")
  end

  defp normalize_attributes(html_node, prefix, key_name, value_name) do
    {_tag, attributes, _children} = html_node

    data =
      Map.new(attributes, fn {name, value} ->
        {name, String.trim_leading(value, "#{prefix}:")}
      end)

    %{data[key_name] => data[value_name]}
  end

  defp maybe_put_title(%{"title" => _} = meta, _), do: meta

  defp maybe_put_title(meta, html) when meta != %{} do
    case get_page_title(html) do
      "" -> meta
      title -> Map.put_new(meta, "title", title)
    end
  end

  defp maybe_put_title(meta, _), do: meta

  defp get_page_title(html) do
    Floki.find(html, "html head title") |> List.first() |> Floki.text()
  end
end
