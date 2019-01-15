defmodule Pleroma.Web.Metadata do
  alias Phoenix.HTML

  @parsers Pleroma.Config.get([:metadata, :providers], [])
  def build_tags(params) do
    Enum.reduce(@parsers, "", fn parser, acc ->
      rendered_html =
        params
        |> parser.build_tags()
        |> Enum.map(&to_tag/1)
        |> Enum.map(&HTML.safe_to_string/1)
        |> Enum.join()

      acc <> rendered_html
    end)
  end

  def to_tag(data) do
    with {name, attrs, _content = []} <- data do
      HTML.Tag.tag(name, attrs)
    else
      {name, attrs, content} ->
        HTML.Tag.content_tag(name, content, attrs)

      _ ->
        raise ArgumentError, message: "make_tag invalid args"
    end
  end
end
