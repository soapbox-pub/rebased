# Pleroma: A lightweight social networking server
# Copyright © 2017-2022 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

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
    "mention u-url",
    "mention hashtag"
  ])

  Meta.allow_tag_with_this_attribute_values(:a, "rel", [
    "tag",
    "nofollow",
    "noopener",
    "noreferrer",
    "ugc"
  ])

  Meta.allow_tag_with_these_attributes(:a, ["name", "title", "lang"])

  Meta.allow_tag_with_these_attributes(:abbr, ["title", "lang"])
  Meta.allow_tag_with_these_attributes(:acronym, ["title", "lang"])

  # sort(1)-ed list
  Meta.allow_tag_with_these_attributes(:bdi, [])
  Meta.allow_tag_with_these_attributes(:bdo, ["dir"])
  Meta.allow_tag_with_these_attributes(:big, ["lang"])
  Meta.allow_tag_with_these_attributes(:b, ["lang"])
  Meta.allow_tag_with_these_attributes(:blockquote, ["lang"])
  Meta.allow_tag_with_these_attributes(:br, ["lang"])
  Meta.allow_tag_with_these_attributes(:cite, ["lang"])
  Meta.allow_tag_with_these_attributes(:code, ["lang"])
  Meta.allow_tag_with_these_attributes(:del, ["lang"])
  Meta.allow_tag_with_these_attributes(:dfn, ["lang"])
  Meta.allow_tag_with_these_attributes(:em, ["lang"])
  Meta.allow_tag_with_these_attributes(:hr, ["lang"])
  Meta.allow_tag_with_these_attributes(:i, ["lang"])
  Meta.allow_tag_with_these_attributes(:ins, ["lang"])
  Meta.allow_tag_with_these_attributes(:kbd, ["lang"])
  Meta.allow_tag_with_these_attributes(:li, ["lang"])
  Meta.allow_tag_with_these_attributes(:ol, ["lang"])
  Meta.allow_tag_with_these_attributes(:p, ["lang"])
  Meta.allow_tag_with_these_attributes(:pre, ["lang"])
  Meta.allow_tag_with_these_attributes(:q, ["lang"])
  Meta.allow_tag_with_these_attributes(:rb, ["lang"])
  Meta.allow_tag_with_these_attributes(:rp, ["lang"])
  Meta.allow_tag_with_these_attributes(:rtc, ["lang"])
  Meta.allow_tag_with_these_attributes(:rt, ["lang"])
  Meta.allow_tag_with_these_attributes(:ruby, ["lang"])
  Meta.allow_tag_with_these_attributes(:samp, ["lang"])
  Meta.allow_tag_with_these_attributes(:s, ["lang"])
  Meta.allow_tag_with_these_attributes(:small, ["lang"])
  Meta.allow_tag_with_these_attributes(:strong, ["lang"])
  Meta.allow_tag_with_these_attributes(:sub, ["lang"])
  Meta.allow_tag_with_these_attributes(:sup, ["lang"])
  Meta.allow_tag_with_these_attributes(:tt, ["lang"])
  Meta.allow_tag_with_these_attributes(:u, ["lang"])
  Meta.allow_tag_with_these_attributes(:ul, ["lang"])
  Meta.allow_tag_with_these_attributes(:var, ["lang"])
  Meta.allow_tag_with_these_attributes(:wbr, ["lang"])

  Meta.allow_tag_with_this_attribute_values(:span, "class", [
    "h-card",
    "recipients-inline",
    "quote-inline"
  ])

  Meta.allow_tag_with_these_attributes(:span, ["lang"])

  Meta.allow_tag_with_this_attribute_values(:code, "class", ["inline"])

  @allow_inline_images Pleroma.Config.get([:markup, :allow_inline_images])

  if @allow_inline_images do
    Meta.allow_tag_with_this_attribute_values(:img, "class", ["emoji"])

    # restrict img tags to http/https only, because of MediaProxy.
    Meta.allow_tag_with_uri_attributes(:img, ["src"], ["http", "https"])

    Meta.allow_tag_with_these_attributes(:img, [
      "width",
      "height",
      "title",
      "alt",
      "lang"
    ])
  end

  if Pleroma.Config.get([:markup, :allow_tables]) do
    Meta.allow_tag_with_these_attributes(:table, ["lang"])
    Meta.allow_tag_with_these_attributes(:tbody, ["lang"])
    Meta.allow_tag_with_these_attributes(:td, ["lang"])
    Meta.allow_tag_with_these_attributes(:th, ["lang"])
    Meta.allow_tag_with_these_attributes(:thead, ["lang"])
    Meta.allow_tag_with_these_attributes(:tr, ["lang"])
  end

  if Pleroma.Config.get([:markup, :allow_headings]) do
    Meta.allow_tag_with_these_attributes(:h1, ["lang"])
    Meta.allow_tag_with_these_attributes(:h2, ["lang"])
    Meta.allow_tag_with_these_attributes(:h3, ["lang"])
    Meta.allow_tag_with_these_attributes(:h4, ["lang"])
    Meta.allow_tag_with_these_attributes(:h5, ["lang"])
  end

  if Pleroma.Config.get([:markup, :allow_fonts]) do
    Meta.allow_tag_with_these_attributes(:font, ["face", "lang"])
  end

  Meta.strip_everything_not_covered()
end
