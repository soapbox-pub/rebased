defmodule Pleroma.HTML do
  alias HtmlSanitizeEx.Scrubber

  @markup Application.get_env(:pleroma, :markup)

  def filter_tags(html) do
    scrubber = Keyword.get(@markup, :scrub_policy)
    html |> Scrubber.scrub(scrubber)
  end

  def strip_tags(html) do
    html |> Scrubber.scrub(Scrubber.StripTags)
  end
end
