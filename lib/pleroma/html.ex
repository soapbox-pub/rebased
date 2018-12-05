defmodule Pleroma.HTML do
  alias HtmlSanitizeEx.Scrubber

  defp get_scrubbers(scrubber) when is_atom(scrubber), do: [scrubber]
  defp get_scrubbers(scrubbers) when is_list(scrubbers), do: scrubbers
  defp get_scrubbers(_), do: [Pleroma.HTML.Scrubber.Default]

  def get_scrubbers() do
    Pleroma.Config.get([:markup, :scrub_policy])
    |> get_scrubbers
  end

  def filter_tags(html, nil) do
    get_scrubbers()
    |> Enum.reduce(html, fn scrubber, html ->
      filter_tags(html, scrubber)
    end)
  end

  def filter_tags(html, scrubber) do
    html |> Scrubber.scrub(scrubber)
  end

  def filter_tags(html), do: filter_tags(html, nil)

  def strip_tags(html) do
    html |> Scrubber.scrub(Scrubber.StripTags)
  end
end

defmodule Pleroma.HTML.Scrubber.TwitterText do
  @moduledoc """
  An HTML scrubbing policy which limits to twitter-style text.  Only
  paragraphs, breaks and links are allowed through the filter.
  """

  @markup Application.get_env(:pleroma, :markup)
  @uri_schemes Application.get_env(:pleroma, :uri_schemes, [])
  @valid_schemes Keyword.get(@uri_schemes, :valid_schemes, [])

  require HtmlSanitizeEx.Scrubber.Meta
  alias HtmlSanitizeEx.Scrubber.Meta

  Meta.remove_cdata_sections_before_scrub()
  Meta.strip_comments()

  # links
  Meta.allow_tag_with_uri_attributes("a", ["href", "data-user", "data-tag"], @valid_schemes)
  Meta.allow_tag_with_these_attributes("a", ["name", "title"])

  # paragraphs and linebreaks
  Meta.allow_tag_with_these_attributes("br", [])
  Meta.allow_tag_with_these_attributes("p", [])

  # microformats
  Meta.allow_tag_with_these_attributes("span", [])

  # allow inline images for custom emoji
  @allow_inline_images Keyword.get(@markup, :allow_inline_images)

  if @allow_inline_images do
    # restrict img tags to http/https only, because of MediaProxy.
    Meta.allow_tag_with_uri_attributes("img", ["src"], ["http", "https"])

    Meta.allow_tag_with_these_attributes("img", [
      "width",
      "height",
      "title",
      "alt"
    ])
  end

  Meta.strip_everything_not_covered()
end

defmodule Pleroma.HTML.Scrubber.Default do
  @doc "The default HTML scrubbing policy: no "

  require HtmlSanitizeEx.Scrubber.Meta
  alias HtmlSanitizeEx.Scrubber.Meta

  @markup Application.get_env(:pleroma, :markup)
  @uri_schemes Application.get_env(:pleroma, :uri_schemes, [])
  @valid_schemes Keyword.get(@uri_schemes, :valid_schemes, [])

  Meta.remove_cdata_sections_before_scrub()
  Meta.strip_comments()

  Meta.allow_tag_with_uri_attributes("a", ["href", "data-user", "data-tag"], @valid_schemes)
  Meta.allow_tag_with_these_attributes("a", ["name", "title"])

  Meta.allow_tag_with_these_attributes("abbr", ["title"])

  Meta.allow_tag_with_these_attributes("b", [])
  Meta.allow_tag_with_these_attributes("blockquote", [])
  Meta.allow_tag_with_these_attributes("br", [])
  Meta.allow_tag_with_these_attributes("code", [])
  Meta.allow_tag_with_these_attributes("del", [])
  Meta.allow_tag_with_these_attributes("em", [])
  Meta.allow_tag_with_these_attributes("i", [])
  Meta.allow_tag_with_these_attributes("li", [])
  Meta.allow_tag_with_these_attributes("ol", [])
  Meta.allow_tag_with_these_attributes("p", [])
  Meta.allow_tag_with_these_attributes("pre", [])
  Meta.allow_tag_with_these_attributes("span", [])
  Meta.allow_tag_with_these_attributes("strong", [])
  Meta.allow_tag_with_these_attributes("u", [])
  Meta.allow_tag_with_these_attributes("ul", [])

  @allow_inline_images Keyword.get(@markup, :allow_inline_images)

  if @allow_inline_images do
    # restrict img tags to http/https only, because of MediaProxy.
    Meta.allow_tag_with_uri_attributes("img", ["src"], ["http", "https"])

    Meta.allow_tag_with_these_attributes("img", [
      "width",
      "height",
      "title",
      "alt"
    ])
  end

  @allow_tables Keyword.get(@markup, :allow_tables)

  if @allow_tables do
    Meta.allow_tag_with_these_attributes("table", [])
    Meta.allow_tag_with_these_attributes("tbody", [])
    Meta.allow_tag_with_these_attributes("td", [])
    Meta.allow_tag_with_these_attributes("th", [])
    Meta.allow_tag_with_these_attributes("thead", [])
    Meta.allow_tag_with_these_attributes("tr", [])
  end

  @allow_headings Keyword.get(@markup, :allow_headings)

  if @allow_headings do
    Meta.allow_tag_with_these_attributes("h1", [])
    Meta.allow_tag_with_these_attributes("h2", [])
    Meta.allow_tag_with_these_attributes("h3", [])
    Meta.allow_tag_with_these_attributes("h4", [])
    Meta.allow_tag_with_these_attributes("h5", [])
  end

  @allow_fonts Keyword.get(@markup, :allow_fonts)

  if @allow_fonts do
    Meta.allow_tag_with_these_attributes("font", ["face"])
  end

  Meta.strip_everything_not_covered()
end

defmodule Pleroma.HTML.Transform.MediaProxy do
  @moduledoc "Transforms inline image URIs to use MediaProxy."

  alias Pleroma.Web.MediaProxy

  def before_scrub(html), do: html

  def scrub_attribute("img", {"src", "http" <> target}) do
    media_url =
      ("http" <> target)
      |> MediaProxy.url()

    {"src", media_url}
  end

  def scrub_attribute(tag, attribute), do: attribute

  def scrub({"img", attributes, children}) do
    attributes =
      attributes
      |> Enum.map(fn attr -> scrub_attribute("img", attr) end)
      |> Enum.reject(&is_nil(&1))

    {"img", attributes, children}
  end

  def scrub({:comment, children}), do: ""

  def scrub({tag, attributes, children}), do: {tag, attributes, children}
  def scrub({tag, children}), do: children
  def scrub(text), do: text
end
