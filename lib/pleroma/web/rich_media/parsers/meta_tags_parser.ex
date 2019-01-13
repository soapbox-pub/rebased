defmodule Pleroma.Web.RichMedia.Parsers.MetaTagsParser do
  def parse(html, data, prefix, error_message, key_name, value_name \\ "content") do
    with elements = [_ | _] <- get_elements(html, key_name, prefix),
         meta_data =
           Enum.reduce(elements, data, fn el, acc ->
             attributes = normalize_attributes(el, prefix, key_name, value_name)

             Map.merge(acc, attributes)
           end) do
      {:ok, meta_data}
    else
      _e -> {:error, error_message}
    end
  end

  defp get_elements(html, key_name, prefix) do
    html |> Floki.find("meta[#{key_name}^='#{prefix}:']")
  end

  defp normalize_attributes(html_node, prefix, key_name, value_name) do
    {_tag, attributes, _children} = html_node

    data =
      Enum.into(attributes, %{}, fn {name, value} ->
        {name, String.trim_leading(value, "#{prefix}:")}
      end)

    %{String.to_atom(data[key_name]) => data[value_name]}
  end
end
