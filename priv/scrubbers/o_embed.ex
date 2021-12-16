defmodule Pleroma.HTML.Scrubber.OEmbed do
  @moduledoc """
  Scrubs OEmbed HTML
  """
  require FastSanitize.Sanitizer.Meta
  alias FastSanitize.Sanitizer.Meta

  Meta.strip_comments()

  Meta.allow_tag_with_these_attributes(:iframe, [
    "width",
    "height",
    "src",
    "allowfullscreen"
  ])

  Meta.strip_everything_not_covered()
end
