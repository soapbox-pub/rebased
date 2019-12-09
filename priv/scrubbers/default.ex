defmodule Pleroma.HTML.Scrubber.Default do
  @doc "The default HTML scrubbing policy: no "

  require FastSanitize.Sanitizer.Meta
  alias FastSanitize.Sanitizer.Meta

  # credo:disable-for-previous-line
  # No idea how to fix this one…

  @valid_schemes Pleroma.Config.get([:uri_schemes, :valid_schemes], [])

  Meta.strip_comments()

  Meta.allow_tag_with_uri_attributes(:a, ["href", "data-user", "data-tag"], @valid_schemes)

  Meta.allow_tag_with_this_attribute_values(:a, "class", [
    "hashtag",
    "u-url",
    "mention",
    "u-url mention",
    "mention u-url"
  ])

  Meta.allow_tag_with_this_attribute_values(:a, "rel", [
    "tag",
    "nofollow",
    "noopener",
    "noreferrer",
    "ugc"
  ])

  Meta.allow_tag_with_these_attributes(:a, ["name", "title"])

  Meta.allow_tag_with_these_attributes(:abbr, ["title"])

  Meta.allow_tag_with_these_attributes(:b, [])
  Meta.allow_tag_with_these_attributes(:blockquote, [])
  Meta.allow_tag_with_these_attributes(:br, [])
  Meta.allow_tag_with_these_attributes(:code, [])
  Meta.allow_tag_with_these_attributes(:del, [])
  Meta.allow_tag_with_these_attributes(:em, [])
  Meta.allow_tag_with_these_attributes(:i, [])
  Meta.allow_tag_with_these_attributes(:li, [])
  Meta.allow_tag_with_these_attributes(:ol, [])
  Meta.allow_tag_with_these_attributes(:p, [])
  Meta.allow_tag_with_these_attributes(:pre, [])
  Meta.allow_tag_with_these_attributes(:strong, [])
  Meta.allow_tag_with_these_attributes(:sub, [])
  Meta.allow_tag_with_these_attributes(:sup, [])
  Meta.allow_tag_with_these_attributes(:u, [])
  Meta.allow_tag_with_these_attributes(:ul, [])

  Meta.allow_tag_with_this_attribute_values(:span, "class", ["h-card"])
  Meta.allow_tag_with_these_attributes(:span, [])

  @allow_inline_images Pleroma.Config.get([:markup, :allow_inline_images])

  if @allow_inline_images do
    # restrict img tags to http/https only, because of MediaProxy.
    Meta.allow_tag_with_uri_attributes(:img, ["src"], ["http", "https"])

    Meta.allow_tag_with_these_attributes(:img, [
      "width",
      "height",
      "class",
      "title",
      "alt"
    ])
  end

  if Pleroma.Config.get([:markup, :allow_tables]) do
    Meta.allow_tag_with_these_attributes(:table, [])
    Meta.allow_tag_with_these_attributes(:tbody, [])
    Meta.allow_tag_with_these_attributes(:td, [])
    Meta.allow_tag_with_these_attributes(:th, [])
    Meta.allow_tag_with_these_attributes(:thead, [])
    Meta.allow_tag_with_these_attributes(:tr, [])
  end

  if Pleroma.Config.get([:markup, :allow_headings]) do
    Meta.allow_tag_with_these_attributes(:h1, [])
    Meta.allow_tag_with_these_attributes(:h2, [])
    Meta.allow_tag_with_these_attributes(:h3, [])
    Meta.allow_tag_with_these_attributes(:h4, [])
    Meta.allow_tag_with_these_attributes(:h5, [])
  end

  if Pleroma.Config.get([:markup, :allow_fonts]) do
    Meta.allow_tag_with_these_attributes(:font, ["face"])
  end

  Meta.strip_everything_not_covered()
end
