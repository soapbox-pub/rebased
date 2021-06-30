# Pleroma: A lightweight social networking server
# Copyright © 2017-2021 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.RichMedia.Parser.MetaTags do
  @doc """
  Parses a `Floki.html_tree/0` and returns a map of raw `<meta>` tag values.
  """
  @spec parse(html_tree :: Floki.html_tree()) :: map()
  def parse(html_tree) do
    html_tree
    |> Floki.find("meta")
    |> Enum.reduce(%{}, fn html_node, acc ->
      case parse_node(html_node) do
        {:ok, {name, content}} -> Map.put(acc, name, content)
        _ -> acc
      end
    end)
    |> clean_data()
  end

  defp parse_node({_tag, attrs, _children}) when is_list(attrs) do
    case Map.new(attrs) do
      %{"name" => name, "content" => content} -> {:ok, {name, content}}
      %{"property" => name, "content" => content} -> {:ok, {name, content}}
      _ -> {:error, :invalid_meta_tag}
    end
  end

  defp parse_node(_), do: {:error, :invalid_meta_tag}

  defp clean_data(data) do
    data
    |> Enum.reject(fn {key, val} ->
      not match?({:ok, _}, Jason.encode(%{key => val}))
    end)
    |> Map.new()
  end
end
