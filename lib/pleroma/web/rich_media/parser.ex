defmodule Pleroma.Web.RichMedia.Parser do
  @parsers [Pleroma.Web.RichMedia.Parsers.OGP]

  def parse(url) do
    Cachex.fetch!(:rich_media_cache, url, fn _ ->
      {:ok, %Tesla.Env{body: html}} = Pleroma.HTTP.get(url)

      result = html |> maybe_parse() |> get_parsed_data()

      {:commit, result}
    end)
  end

  defp maybe_parse(html) do
    Enum.reduce_while(@parsers, %{}, fn parser, acc ->
      case parser.parse(html, acc) do
        {:ok, data} -> {:halt, data}
        {:error, _msg} -> {:cont, acc}
      end
    end)
  end

  defp get_parsed_data(data) when data == %{} do
    {:error, "No metadata found"}
  end

  defp get_parsed_data(data) do
    {:ok, data}
  end
end
