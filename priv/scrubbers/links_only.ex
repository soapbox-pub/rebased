defmodule Pleroma.HTML.Scrubber.LinksOnly do
  @moduledoc """
  An HTML scrubbing policy which limits to links only.
  """

  @valid_schemes Pleroma.Config.get([:uri_schemes, :valid_schemes], [])

  require FastSanitize.Sanitizer.Meta
  alias FastSanitize.Sanitizer.Meta

  Meta.strip_comments()

  # links
  Meta.allow_tag_with_uri_attributes(:a, ["href"], @valid_schemes)

  Meta.allow_tag_with_this_attribute_values(:a, "rel", [
    "tag",
    "nofollow",
    "noopener",
    "noreferrer",
    "me",
    "ugc"
  ])

  Meta.allow_tag_with_these_attributes(:a, ["name", "title"])
  Meta.strip_everything_not_covered()
end
