defmodule Pleroma.Web.RichMedia.Parsers.OGP do
  def parse(html, data) do
    with elements = [_ | _] <- get_elements(html),
         ogp_data =
           Enum.reduce(elements, data, fn el, acc ->
             attributes = normalize_attributes(el)

             Map.merge(acc, attributes)
           end) do
      {:ok, ogp_data}
    else
      _e -> {:error, "No OGP metadata found"}
    end
  end

  defp get_elements(html) do
    html |> Floki.find("meta[property^='og:']")
  end

  defp normalize_attributes(tuple) do
    {_tag, attributes, _children} = tuple

    data =
      Enum.into(attributes, %{}, fn {name, value} ->
        {name, String.trim_leading(value, "og:")}
      end)

    %{String.to_atom(data["property"]) => data["content"]}
  end
end
