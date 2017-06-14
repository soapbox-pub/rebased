defmodule Pleroma.Formatter do
  alias Pleroma.User

  @link_regex ~r/https?:\/\/[\w\.\/?=\-#]+[\w]/
  def linkify(text) do
    Regex.replace(@link_regex, text, "<a href='\\0'>\\0</a>")
  end

  @tag_regex ~r/\#\w+/u
  def parse_tags(text) do
    Regex.scan(@tag_regex, text)
    |> Enum.map(fn (["#" <> tag = full_tag]) -> {full_tag, tag} end)
  end

  def parse_mentions(text) do
    # Modified from https://www.w3.org/TR/html5/forms.html#valid-e-mail-address
    regex = ~r/@[a-zA-Z0-9.!#$%&'*+\/=?^_`{|}~-]+@?[a-zA-Z0-9](?:[a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?(?:\.[a-zA-Z0-9](?:[a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?)*/

    Regex.scan(regex, text)
    |> List.flatten
    |> Enum.uniq
    |> Enum.map(fn ("@" <> match = full_match) -> {full_match, User.get_cached_by_nickname(match)} end)
    |> Enum.filter(fn ({_match, user}) -> user end)
  end
end
