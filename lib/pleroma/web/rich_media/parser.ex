defmodule Pleroma.Web.RichMedia.Parser do
  @parsers [Pleroma.Web.RichMedia.Parsers.OGP]

  def parse(url) do
    {:ok, %Tesla.Env{body: html}} = Pleroma.HTTP.get(url)

    Enum.reduce_while(@parsers, %Pleroma.Web.RichMedia.Data{}, fn parser, acc ->
      case parser.parse(html, acc) do
        {:ok, data} -> {:halt, data}
        {:error, _msg} -> {:cont, acc}
      end
    end)
  end
end
