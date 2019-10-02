# Pleroma: A lightweight social networking server
# Copyright © 2017-2019 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.HTML do
  alias HtmlSanitizeEx.Scrubber

  defp get_scrubbers(scrubber) when is_atom(scrubber), do: [scrubber]
  defp get_scrubbers(scrubbers) when is_list(scrubbers), do: scrubbers
  defp get_scrubbers(_), do: [Pleroma.HTML.Scrubber.Default]

  def get_scrubbers do
    Pleroma.Config.get([:markup, :scrub_policy])
    |> get_scrubbers
  end

  def filter_tags(html, nil) do
    filter_tags(html, get_scrubbers())
  end

  def filter_tags(html, scrubbers) when is_list(scrubbers) do
    Enum.reduce(scrubbers, html, fn scrubber, html ->
      filter_tags(html, scrubber)
    end)
  end

  def filter_tags(html, scrubber), do: Scrubber.scrub(html, scrubber)
  def filter_tags(html), do: filter_tags(html, nil)
  def strip_tags(html), do: Scrubber.scrub(html, Scrubber.StripTags)

  def get_cached_scrubbed_html_for_activity(
        content,
        scrubbers,
        activity,
        key \\ "",
        callback \\ fn x -> x end
      ) do
    key = "#{key}#{generate_scrubber_signature(scrubbers)}|#{activity.id}"

    Cachex.fetch!(:scrubber_cache, key, fn _key ->
      object = Pleroma.Object.normalize(activity)
      ensure_scrubbed_html(content, scrubbers, object.data["fake"] || false, callback)
    end)
  end

  def get_cached_stripped_html_for_activity(content, activity, key) do
    get_cached_scrubbed_html_for_activity(
      content,
      HtmlSanitizeEx.Scrubber.StripTags,
      activity,
      key,
      &HtmlEntities.decode/1
    )
  end

  def ensure_scrubbed_html(
        content,
        scrubbers,
        fake,
        callback
      ) do
    content =
      content
      |> filter_tags(scrubbers)
      |> callback.()

    if fake do
      {:ignore, content}
    else
      {:commit, content}
    end
  end

  defp generate_scrubber_signature(scrubber) when is_atom(scrubber) do
    generate_scrubber_signature([scrubber])
  end

  defp generate_scrubber_signature(scrubbers) do
    Enum.reduce(scrubbers, "", fn scrubber, signature ->
      "#{signature}#{to_string(scrubber)}"
    end)
  end

  def extract_first_external_url(_, nil), do: {:error, "No content"}

  def extract_first_external_url(object, content) do
    key = "URL|#{object.id}"

    Cachex.fetch!(:scrubber_cache, key, fn _key ->
      result =
        content
        |> Floki.filter_out("a.mention,a.hashtag,a[rel~=\"tag\"]")
        |> Floki.attribute("a", "href")
        |> Enum.at(0)

      {:commit, {:ok, result}}
    end)
  end
end

defmodule Pleroma.HTML.Scrubber.TwitterText do
  @moduledoc """
  An HTML scrubbing policy which limits to twitter-style text.  Only
  paragraphs, breaks and links are allowed through the filter.
  """

  @valid_schemes Pleroma.Config.get([:uri_schemes, :valid_schemes], [])

  require HtmlSanitizeEx.Scrubber.Meta
  alias HtmlSanitizeEx.Scrubber.Meta

  Meta.remove_cdata_sections_before_scrub()
  Meta.strip_comments()

  # links
  Meta.allow_tag_with_uri_attributes("a", ["href", "data-user", "data-tag"], @valid_schemes)

  Meta.allow_tag_with_this_attribute_values("a", "class", [
    "hashtag",
    "u-url",
    "mention",
    "u-url mention",
    "mention u-url"
  ])

  Meta.allow_tag_with_this_attribute_values("a", "rel", [
    "tag",
    "nofollow",
    "noopener",
    "noreferrer"
  ])

  Meta.allow_tag_with_these_attributes("a", ["name", "title"])

  # paragraphs and linebreaks
  Meta.allow_tag_with_these_attributes("br", [])
  Meta.allow_tag_with_these_attributes("p", [])

  # microformats
  Meta.allow_tag_with_this_attribute_values("span", "class", ["h-card"])
  Meta.allow_tag_with_these_attributes("span", [])

  # allow inline images for custom emoji
  if Pleroma.Config.get([:markup, :allow_inline_images]) do
    # restrict img tags to http/https only, because of MediaProxy.
    Meta.allow_tag_with_uri_attributes("img", ["src"], ["http", "https"])

    Meta.allow_tag_with_these_attributes("img", [
      "width",
      "height",
      "class",
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
  # credo:disable-for-previous-line
  # No idea how to fix this one…

  @valid_schemes Pleroma.Config.get([:uri_schemes, :valid_schemes], [])

  Meta.remove_cdata_sections_before_scrub()
  Meta.strip_comments()

  Meta.allow_tag_with_uri_attributes("a", ["href", "data-user", "data-tag"], @valid_schemes)

  Meta.allow_tag_with_this_attribute_values("a", "class", [
    "hashtag",
    "u-url",
    "mention",
    "u-url mention",
    "mention u-url"
  ])

  Meta.allow_tag_with_this_attribute_values("a", "rel", [
    "tag",
    "nofollow",
    "noopener",
    "noreferrer",
    "ugc"
  ])

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
  Meta.allow_tag_with_these_attributes("strong", [])
  Meta.allow_tag_with_these_attributes("sub", [])
  Meta.allow_tag_with_these_attributes("sup", [])
  Meta.allow_tag_with_these_attributes("u", [])
  Meta.allow_tag_with_these_attributes("ul", [])

  Meta.allow_tag_with_this_attribute_values("span", "class", ["h-card"])
  Meta.allow_tag_with_these_attributes("span", [])

  @allow_inline_images Pleroma.Config.get([:markup, :allow_inline_images])

  if @allow_inline_images do
    # restrict img tags to http/https only, because of MediaProxy.
    Meta.allow_tag_with_uri_attributes("img", ["src"], ["http", "https"])

    Meta.allow_tag_with_these_attributes("img", [
      "width",
      "height",
      "class",
      "title",
      "alt"
    ])
  end

  if Pleroma.Config.get([:markup, :allow_tables]) do
    Meta.allow_tag_with_these_attributes("table", [])
    Meta.allow_tag_with_these_attributes("tbody", [])
    Meta.allow_tag_with_these_attributes("td", [])
    Meta.allow_tag_with_these_attributes("th", [])
    Meta.allow_tag_with_these_attributes("thead", [])
    Meta.allow_tag_with_these_attributes("tr", [])
  end

  if Pleroma.Config.get([:markup, :allow_headings]) do
    Meta.allow_tag_with_these_attributes("h1", [])
    Meta.allow_tag_with_these_attributes("h2", [])
    Meta.allow_tag_with_these_attributes("h3", [])
    Meta.allow_tag_with_these_attributes("h4", [])
    Meta.allow_tag_with_these_attributes("h5", [])
  end

  if Pleroma.Config.get([:markup, :allow_fonts]) do
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

  def scrub_attribute(_tag, attribute), do: attribute

  def scrub({"img", attributes, children}) do
    attributes =
      attributes
      |> Enum.map(fn attr -> scrub_attribute("img", attr) end)
      |> Enum.reject(&is_nil(&1))

    {"img", attributes, children}
  end

  def scrub({:comment, _children}), do: ""

  def scrub({tag, attributes, children}), do: {tag, attributes, children}
  def scrub({_tag, children}), do: children
  def scrub(text), do: text
end

defmodule Pleroma.HTML.Scrubber.LinksOnly do
  @moduledoc """
  An HTML scrubbing policy which limits to links only.
  """

  @valid_schemes Pleroma.Config.get([:uri_schemes, :valid_schemes], [])

  require HtmlSanitizeEx.Scrubber.Meta
  alias HtmlSanitizeEx.Scrubber.Meta

  Meta.remove_cdata_sections_before_scrub()
  Meta.strip_comments()

  # links
  Meta.allow_tag_with_uri_attributes("a", ["href"], @valid_schemes)

  Meta.allow_tag_with_this_attribute_values("a", "rel", [
    "tag",
    "nofollow",
    "noopener",
    "noreferrer",
    "me",
    "ugc"
  ])

  Meta.allow_tag_with_these_attributes("a", ["name", "title"])
  Meta.strip_everything_not_covered()
end
