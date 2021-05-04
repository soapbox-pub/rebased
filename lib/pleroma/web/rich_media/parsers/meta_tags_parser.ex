# Pleroma: A lightweight social networking server
# Copyright © 2017-2021 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.RichMedia.Parsers.MetaTagsParser do
  def parse(html, prefix, key_name, value_name \\ "content") do
    html
    |> get_elements(key_name, prefix)
    |> Enum.reduce(%{}, fn el, acc ->
      attributes = normalize_attributes(el, key_name, value_name)
      Map.merge(acc, attributes)
    end)
  end

  defp get_elements(html, key_names, prefix) when is_list(key_names) do
    Enum.reduce(key_names, [], fn key_name, acc ->
      acc ++ Floki.find(html, "meta[#{key_name}^='#{prefix}:']")
    end)
  end

  defp get_elements(html, key_name, prefix) do
    get_elements(html, [key_name], prefix)
  end

  defp normalize_attributes(html_node, key_names, value_name) when is_list(key_names) do
    {_tag, attributes, _children} = html_node
    data = Map.new(attributes)

    Enum.reduce(key_names, %{}, fn key_name, acc ->
      if data[key_name], do: Map.put(acc, data[key_name], data[value_name]), else: acc
    end)
  end

  defp normalize_attributes(html_node, key_name, value_name) do
    normalize_attributes(html_node, [key_name], value_name)
  end

  def get_page_title(html) do
    Floki.find(html, "html head title") |> List.first() |> Floki.text()
  end
end
