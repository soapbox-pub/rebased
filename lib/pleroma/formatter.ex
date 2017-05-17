defmodule Pleroma.Formatter do

  @link_regex ~r/https?:\/\/[\w\.\/?=\-#]+[\w]/
  def linkify(text) do
    Regex.replace(@link_regex, text, "<a href='\\0'>\\0</a>")
  end

  @tag_regex ~r/\#\w+/u
  def parse_tags(text) do
    Regex.scan(@tag_regex, text)
    |> Enum.map(fn (["#" <> tag = full_tag]) -> {full_tag, tag} end)
  end
end
